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
        let existing = draft.alarmID.flatMap { id in alarms.first { $0.id == id } }
        var alarm = draft.makeAlarm(existing: existing)
        alarm.scheduledOccurrenceIDs = []
        alarm.scheduledThrough = nil
        alarm.nextFireDate = nil
        alarm.lastScheduledAt = nil

        await cancelStoredOccurrences(for: existing)

        if alarm.isEnabled {
            alarm = await schedule(
                alarm,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            )
        }

        replace(alarm)
    }

    func setAlarm(
        _ alarm: SmartAlarm,
        enabled: Bool,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = []
    ) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }

        var updated = alarms[index]
        await cancelStoredOccurrences(for: updated)
        updated.isEnabled = enabled
        updated.scheduledOccurrenceIDs = []
        updated.scheduledThrough = nil
        updated.nextFireDate = nil
        updated.lastScheduledAt = nil

        if enabled {
            updated = await schedule(
                updated,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            )
        } else {
            statusMessage = "已关闭 \(updated.displayTitle)"
        }

        alarms[index] = updated
    }

    func deleteAlarm(_ alarm: SmartAlarm) async {
        await cancelStoredOccurrences(for: alarm)
        alarms.removeAll { $0.id == alarm.id }
        statusMessage = "已删除 \(alarm.displayTitle)"
    }

    func refreshSchedules(
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = []
    ) async {
        guard alarms.contains(where: \.isEnabled) else { return }

        isScheduling = true
        defer { isScheduling = false }

        for alarm in alarms where alarm.isEnabled {
            await cancelStoredOccurrences(for: alarm)
            let updated = await schedule(
                alarm,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys,
                updatesSchedulingState: false
            )
            replace(updated)
        }
    }

    private func schedule(
        _ alarm: SmartAlarm,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = [],
        updatesSchedulingState: Bool = true
    ) async -> SmartAlarm {
        var updated = alarm
        if updatesSchedulingState {
            isScheduling = true
        }
        defer {
            if updatesSchedulingState {
                isScheduling = false
            }
        }

        do {
            let outcome = try await AlarmKitScheduler.schedule(
                alarm: alarm,
                skipping: holidays,
                spanDaysByID: spanDaysByID,
                makeupWorkDateKeys: makeupWorkDateKeys
            )
            updated.scheduledOccurrenceIDs = outcome.scheduledOccurrenceIDs
            updated.scheduledThrough = outcome.coverageThrough
            updated.nextFireDate = outcome.nextFireDate
            updated.lastScheduledAt = Date()
            statusMessage = makeStatusMessage(for: updated, outcome: outcome)
        } catch {
            updated.isEnabled = false
            updated.scheduledOccurrenceIDs = []
            statusMessage = error.localizedDescription
        }

        return updated
    }

    private func cancelStoredOccurrences(for alarm: SmartAlarm?) async {
        guard let alarm, !alarm.scheduledOccurrenceIDs.isEmpty else { return }
        try? await AlarmKitScheduler.cancel(ids: alarm.scheduledOccurrenceIDs)
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

        let skipped = outcome.skippedHolidayOccurrences.count
        if skipped > 0 {
            return "已为 \(alarm.displayTitle) 排入 \(outcome.scheduledDates.count) 个闹钟，跳过 \(skipped) 个节日。"
        }

        return "已为 \(alarm.displayTitle) 排入 \(outcome.scheduledDates.count) 个闹钟。"
    }

    private func persist() {
        let configuration = AlarmConfigurationStore(alarms: alarms, updatedAt: Date())
        guard let data = try? JSONEncoder.holidayEncoder.encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
