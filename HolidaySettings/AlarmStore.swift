import Foundation
import Combine

@MainActor
final class AlarmStore: ObservableObject {
    @Published var alarms: [SmartAlarm] {
        didSet { persist() }
    }

    @Published var statusMessage: String?
    @Published var isScheduling = false

    private let defaults: UserDefaults
    private let storageKey = "cn.holiday.settings.alarms.v1"
    private let schedulingLock = AlarmSchedulingOperationLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: storageKey),
            let configuration = try? JSONDecoder.holidayDecoder.decode(AlarmConfigurationStore.self, from: data)
        {
            self.alarms = configuration.alarms
        } else {
            self.alarms = [SmartAlarm()]
        }
    }

    func upsertAlarm(
        _ draft: AlarmDraft,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = []
    ) async {
        await beginSchedulingOperation()
        defer { endSchedulingOperation() }

        let existing = draft.alarmID.flatMap { id in alarms.first { $0.id == id } }
        let previousOccurrenceIDs = existing?.scheduledOccurrenceIDs ?? []
        var alarm = withoutScheduleMetadata(draft.makeAlarm(existing: existing))

        if alarm.isEnabled {
            switch await makeScheduledAlarm(
                alarm,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            ) {
            case .success(let result):
                await cancelOccurrences(ids: previousOccurrenceIDs)
                replace(result.alarm)
                statusMessage = makeStatusMessage(for: result.alarm, outcome: result.outcome)
            case .failure(let error):
                statusMessage = error.localizedDescription
                if existing == nil || existing?.isEnabled == false {
                    alarm.isEnabled = false
                    replace(alarm)
                }
            }
        } else {
            await cancelOccurrences(ids: previousOccurrenceIDs)
            replace(alarm)
            statusMessage = "已保存 \(alarm.displayTitle)"
        }
    }

    func setAlarm(
        _ alarm: SmartAlarm,
        enabled: Bool,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = []
    ) async {
        await beginSchedulingOperation()
        defer { endSchedulingOperation() }

        guard let current = alarms.first(where: { $0.id == alarm.id }) else { return }
        let previousOccurrenceIDs = current.scheduledOccurrenceIDs
        var updated = withoutScheduleMetadata(current)
        updated.isEnabled = enabled

        if enabled {
            switch await makeScheduledAlarm(
                updated,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            ) {
            case .success(let result):
                await cancelOccurrences(ids: previousOccurrenceIDs)
                replace(result.alarm)
                statusMessage = makeStatusMessage(for: result.alarm, outcome: result.outcome)
            case .failure(let error):
                statusMessage = error.localizedDescription
                if previousOccurrenceIDs.isEmpty {
                    updated.isEnabled = false
                    replace(updated)
                }
            }
        } else {
            await cancelOccurrences(ids: previousOccurrenceIDs)
            replace(updated)
            statusMessage = "已关闭 \(updated.displayTitle)"
        }
    }

    func deleteAlarm(_ alarm: SmartAlarm) async {
        await beginSchedulingOperation()
        defer { endSchedulingOperation() }

        guard let current = alarms.first(where: { $0.id == alarm.id }) else { return }
        await cancelOccurrences(ids: current.scheduledOccurrenceIDs)
        alarms.removeAll { $0.id == alarm.id }
        statusMessage = "已删除 \(alarm.displayTitle)"
    }

    func refreshSchedules(
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = []
    ) async {
        await beginSchedulingOperation()
        defer { endSchedulingOperation() }

        guard alarms.contains(where: \.isEnabled) else { return }

        var syncedCount = 0
        var failureMessages: [String] = []

        for alarm in alarms.filter(\.isEnabled) {
            guard alarms.contains(where: { $0.id == alarm.id }) else { continue }

            switch await makeScheduledAlarm(
                alarm,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            ) {
            case .success(let result):
                await cancelOccurrences(ids: alarm.scheduledOccurrenceIDs)
                replace(result.alarm)
                syncedCount += 1
            case .failure(let error):
                failureMessages.append("\(alarm.displayTitle)：\(error.localizedDescription)")
            }
        }

        statusMessage = makeRefreshStatusMessage(syncedCount: syncedCount, failureMessages: failureMessages)
    }

    func refreshSchedulesIfNeeded(
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = [],
        now: Date = Date(),
        renewalLeadDays: Int = 14,
        calendar: Calendar = .autoupdatingCurrent
    ) async {
        let renewalThreshold = calendar.date(byAdding: .day, value: renewalLeadDays, to: now) ?? now
        let needsRefresh = alarms.contains { alarm in
            guard alarm.isEnabled else { return false }

            if alarm.scheduledOccurrenceIDs.isEmpty || alarm.nextFireDate == nil || alarm.scheduledThrough == nil {
                return true
            }

            if let nextFireDate = alarm.nextFireDate, nextFireDate <= now {
                return true
            }

            if let scheduledThrough = alarm.scheduledThrough, scheduledThrough <= renewalThreshold {
                return true
            }

            return false
        }

        guard needsRefresh else { return }
        await refreshSchedules(
            skipping: holidays,
            spanDaysByID: spanDaysByID,
            makeupWorkDateKeys: makeupWorkDateKeys
        )
    }

    private func makeScheduledAlarm(
        _ alarm: SmartAlarm,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = []
    ) async -> Result<ScheduledAlarmResult, Error> {
        var updated = withoutScheduleMetadata(alarm)

        do {
            let outcome = try await AlarmKitScheduler.schedule(
                alarm: updated,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            )
            updated.scheduledOccurrenceIDs = outcome.scheduledOccurrenceIDs
            updated.scheduledThrough = outcome.coverageThrough
            updated.nextFireDate = outcome.nextFireDate
            updated.lastScheduledAt = Date()
            return .success(ScheduledAlarmResult(alarm: updated, outcome: outcome))
        } catch {
            return .failure(error)
        }
    }

    private func withoutScheduleMetadata(_ alarm: SmartAlarm) -> SmartAlarm {
        var updated = alarm
        updated.scheduledOccurrenceIDs = []
        updated.scheduledThrough = nil
        updated.nextFireDate = nil
        updated.lastScheduledAt = nil
        return updated
    }

    private func cancelOccurrences(ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        try? await AlarmKitScheduler.cancel(ids: ids)
    }

    private func replace(_ alarm: SmartAlarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
    }

    private func makeStatusMessage(for alarm: SmartAlarm, outcome: AlarmScheduleOutcome) -> String {
        if outcome.scheduledDates.isEmpty {
            return "\(alarm.displayTitle) 没有可调度日期，请检查重复日期或免闹钟节日。"
        }

        let scheduledCount = outcome.scheduledDates.count
        let skippedCount = outcome.skippedHolidayOccurrences.count
        if let scheduledThrough = alarm.scheduledThrough {
            let throughText = scheduledThrough.formatted(date: .abbreviated, time: .omitted)
            if skippedCount > 0 {
                return "已为 \(alarm.displayTitle) 排入 \(scheduledCount) 个闹钟，跳过 \(skippedCount) 个节假日，覆盖至 \(throughText)。"
            }
            return "已为 \(alarm.displayTitle) 排入 \(scheduledCount) 个闹钟，覆盖至 \(throughText)。"
        }

        return "已为 \(alarm.displayTitle) 排入 \(scheduledCount) 个闹钟。"
    }

    private func makeRefreshStatusMessage(syncedCount: Int, failureMessages: [String]) -> String {
        if failureMessages.isEmpty {
            return "已同步 \(syncedCount) 个闹钟。"
        }

        if syncedCount == 0 {
            return failureMessages.first ?? "闹钟同步失败。"
        }

        return "已同步 \(syncedCount) 个闹钟，\(failureMessages.count) 个失败：\(failureMessages[0])"
    }

    private func beginSchedulingOperation() async {
        await schedulingLock.acquire()
        isScheduling = true
    }

    private func endSchedulingOperation() {
        isScheduling = false
        Task {
            await schedulingLock.release()
        }
    }

    private func persist() {
        let configuration = AlarmConfigurationStore(alarms: alarms, updatedAt: Date())
        guard let data = try? JSONEncoder.holidayEncoder.encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private struct ScheduledAlarmResult {
    let alarm: SmartAlarm
    let outcome: AlarmScheduleOutcome
}

private actor AlarmSchedulingOperationLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
