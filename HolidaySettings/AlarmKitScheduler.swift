import Foundation

#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

struct AlarmSchedulePlan: Equatable {
    var fireDates: [Date]
    var skippedHolidayOccurrences: [HolidayOccurrence]
    var coverageThrough: Date

    var nextFireDate: Date? {
        fireDates.first
    }
}

struct AlarmScheduleOutcome: Equatable {
    var scheduledOccurrenceIDs: [UUID]
    var scheduledDates: [Date]
    var skippedHolidayOccurrences: [HolidayOccurrence]
    var coverageThrough: Date

    var nextFireDate: Date? {
        scheduledDates.first
    }
}

enum AlarmSchedulingError: LocalizedError {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "当前环境不支持 iOS 26 AlarmKit。请在 Xcode 26 和 iOS 26 设备上运行。"
        case .notAuthorized:
            return "没有获得闹钟权限，无法调度系统闹钟。"
        }
    }
}

enum AlarmKitScheduler {
    static let horizonDays = 90
    static let maxScheduledOccurrences = 64

    static func makePlan(
        for alarm: SmartAlarm,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = [],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> AlarmSchedulePlan {
        let resolver = HolidayDateResolver(calendar: calendar)
        let coverageThrough = calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
        let holidaysByDate = alarm.skipsSelectedHolidays
            ? Dictionary(
                grouping: resolver.occurrences(
                    for: holidays,
                    from: now,
                    through: coverageThrough,
                    spanDaysByID: spanDaysByID
                ),
                by: \.dateKey
            )
            : [:]

        var fireDates: [Date] = []
        var skippedOccurrences: [HolidayOccurrence] = []
        var date = calendar.startOfDay(for: now)

        while date <= coverageThrough && fireDates.count < maxScheduledOccurrences {
            let weekday = calendar.component(.weekday, from: date)
            if
                let alarmWeekday = AlarmWeekday.from(calendarWeekday: weekday),
                alarm.repeatWeekdays.contains(alarmWeekday)
            {
                if let fireDate = alarmFireDate(on: date, alarm: alarm, calendar: calendar), fireDate > now {
                    let dateKey = resolver.dateKey(for: date)
                    if
                        let holidayOccurrences = holidaysByDate[dateKey],
                        !holidayOccurrences.isEmpty,
                        !makeupWorkDateKeys.contains(dateKey)
                    {
                        skippedOccurrences.append(contentsOf: holidayOccurrences)
                    } else {
                        fireDates.append(fireDate)
                    }
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDay
        }

        return AlarmSchedulePlan(
            fireDates: fireDates,
            skippedHolidayOccurrences: skippedOccurrences,
            coverageThrough: coverageThrough
        )
    }

    static func requestAuthorization() async throws -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let state = try await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        }
        #endif

        throw AlarmSchedulingError.unavailable
    }

    static func schedule(
        alarm: SmartAlarm,
        skipping holidays: [ChinaHoliday],
        spanDaysByID: [String: Int] = [:],
        makeupWorkDateKeys: Set<String> = [],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> AlarmScheduleOutcome {
        let isAuthorized = try await requestAuthorization()
        guard isAuthorized else { throw AlarmSchedulingError.notAuthorized }

        let plan = makePlan(
            for: alarm,
            skipping: holidays,
            spanDaysByID: spanDaysByID,
            makeupWorkDateKeys: makeupWorkDateKeys,
            now: now,
            calendar: calendar
        )
        var scheduledIDs: [UUID] = []

        for fireDate in plan.fireDates {
            let occurrenceID = UUID()
            try await scheduleOccurrence(id: occurrenceID, alarm: alarm, fireDate: fireDate)
            scheduledIDs.append(occurrenceID)
        }

        return AlarmScheduleOutcome(
            scheduledOccurrenceIDs: scheduledIDs,
            scheduledDates: plan.fireDates,
            skippedHolidayOccurrences: plan.skippedHolidayOccurrences,
            coverageThrough: plan.coverageThrough
        )
    }

    static func cancel(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            for id in ids {
                try? AlarmManager.shared.cancel(id: id)
            }
            return
        }
        #endif

        throw AlarmSchedulingError.unavailable
    }

    private static func alarmFireDate(on date: Date, alarm: SmartAlarm, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0
        return calendar.date(from: components)
    }

    private static func scheduleOccurrence(id: UUID, alarm: SmartAlarm, fireDate: Date) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alarm.displayTitle)
            )
            let presentation = AlarmPresentation(alert: alert)
            let attributes: AlarmAttributes<SmartAlarmMetadata> = AlarmAttributes(
                presentation: presentation,
                metadata: SmartAlarmMetadata(
                    alarmID: alarm.id.uuidString,
                    title: alarm.displayTitle
                ),
                tintColor: .orange
            )
            let configuration: AlarmManager.AlarmConfiguration<SmartAlarmMetadata> = .alarm(
                schedule: .fixed(fireDate),
                attributes: attributes,
                sound: .default
            )
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            return
        }
        #endif

        throw AlarmSchedulingError.unavailable
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct SmartAlarmMetadata: AlarmMetadata, Codable, Hashable, Sendable {
    let alarmID: String
    let title: String
}
#endif
