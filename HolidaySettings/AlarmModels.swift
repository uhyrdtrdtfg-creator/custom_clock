import Foundation

enum AlarmWeekday: Int, Codable, CaseIterable, Identifiable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday:
            return "星期日"
        case .monday:
            return "星期一"
        case .tuesday:
            return "星期二"
        case .wednesday:
            return "星期三"
        case .thursday:
            return "星期四"
        case .friday:
            return "星期五"
        case .saturday:
            return "星期六"
        }
    }

    var shortTitle: String {
        switch self {
        case .sunday:
            return "日"
        case .monday:
            return "一"
        case .tuesday:
            return "二"
        case .wednesday:
            return "三"
        case .thursday:
            return "四"
        case .friday:
            return "五"
        case .saturday:
            return "六"
        }
    }

    static let workdays: Set<AlarmWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<AlarmWeekday> = [.saturday, .sunday]

    static func from(calendarWeekday: Int) -> AlarmWeekday? {
        AlarmWeekday(rawValue: calendarWeekday)
    }
}

struct SmartAlarm: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var repeatWeekdays: Set<AlarmWeekday>
    var skipsSelectedHolidays: Bool
    var isEnabled: Bool
    var scheduledOccurrenceIDs: [UUID]
    var scheduledThrough: Date?
    var nextFireDate: Date?
    var lastScheduledAt: Date?

    init(
        id: UUID = UUID(),
        title: String = "工作日闹钟",
        hour: Int = 8,
        minute: Int = 0,
        repeatWeekdays: Set<AlarmWeekday> = AlarmWeekday.workdays,
        skipsSelectedHolidays: Bool = true,
        isEnabled: Bool = false,
        scheduledOccurrenceIDs: [UUID] = [],
        scheduledThrough: Date? = nil,
        nextFireDate: Date? = nil,
        lastScheduledAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.repeatWeekdays = repeatWeekdays
        self.skipsSelectedHolidays = skipsSelectedHolidays
        self.isEnabled = isEnabled
        self.scheduledOccurrenceIDs = scheduledOccurrenceIDs
        self.scheduledThrough = scheduledThrough
        self.nextFireDate = nextFireDate
        self.lastScheduledAt = lastScheduledAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "闹钟" : trimmed
    }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatText: String {
        if repeatWeekdays == Set(AlarmWeekday.allCases) {
            return "每天"
        }

        if repeatWeekdays == AlarmWeekday.workdays {
            return "工作日"
        }

        if repeatWeekdays == AlarmWeekday.weekend {
            return "周末"
        }

        if repeatWeekdays.isEmpty {
            return "未选择重复日期"
        }

        return AlarmWeekday.allCases
            .filter { repeatWeekdays.contains($0) }
            .map(\.shortTitle)
            .joined(separator: " ")
    }
}

struct AlarmConfigurationStore: Codable, Equatable {
    var alarms: [SmartAlarm]
    var updatedAt: Date
}

struct AlarmDraft: Identifiable, Equatable {
    let id: UUID
    var alarmID: UUID?
    var title: String
    var time: Date
    var repeatWeekdays: Set<AlarmWeekday>
    var skipsSelectedHolidays: Bool
    var isEnabled: Bool

    init(alarm: SmartAlarm? = nil, calendar: Calendar = .autoupdatingCurrent) {
        self.id = UUID()
        self.alarmID = alarm?.id
        self.title = alarm?.title ?? "工作日闹钟"
        self.repeatWeekdays = alarm?.repeatWeekdays ?? AlarmWeekday.workdays
        self.skipsSelectedHolidays = alarm?.skipsSelectedHolidays ?? true
        self.isEnabled = alarm?.isEnabled ?? true

        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = alarm?.hour ?? 8
        components.minute = alarm?.minute ?? 0
        components.second = 0
        self.time = calendar.date(from: components) ?? Date()
    }

    var isValid: Bool {
        !repeatWeekdays.isEmpty
    }

    func makeAlarm(existing: SmartAlarm? = nil, calendar: Calendar = .autoupdatingCurrent) -> SmartAlarm {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return SmartAlarm(
            id: alarmID ?? existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: components.hour ?? existing?.hour ?? 8,
            minute: components.minute ?? existing?.minute ?? 0,
            repeatWeekdays: repeatWeekdays,
            skipsSelectedHolidays: skipsSelectedHolidays,
            isEnabled: isEnabled,
            scheduledOccurrenceIDs: existing?.scheduledOccurrenceIDs ?? [],
            scheduledThrough: existing?.scheduledThrough,
            nextFireDate: existing?.nextFireDate,
            lastScheduledAt: existing?.lastScheduledAt
        )
    }
}
