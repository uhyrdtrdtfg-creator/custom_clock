import Foundation

enum HolidayCalendarKind: String, Codable, CaseIterable, Identifiable {
    case solar
    case lunar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solar:
            return "公历"
        case .lunar:
            return "农历"
        }
    }
}

struct HolidayDateRule: Codable, Hashable {
    var calendar: HolidayCalendarKind
    var month: Int
    var day: Int?
    var specialDescription: String?

    var displayText: String {
        if let specialDescription {
            return specialDescription
        }

        guard let day else {
            return "\(calendar.title) \(month)月"
        }

        return "\(calendar.title) \(month)月\(day)日"
    }
}

struct ChinaHoliday: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var dateRule: HolidayDateRule
    var isCustom: Bool
    var note: String

    var calendarTitle: String {
        dateRule.calendar.title
    }

    static let builtIn: [ChinaHoliday] = [
        ChinaHoliday(
            id: "new-year",
            name: "元旦",
            dateRule: HolidayDateRule(calendar: .solar, month: 1, day: 1),
            isCustom: false,
            note: "公历新年"
        ),
        ChinaHoliday(
            id: "spring-festival",
            name: "春节",
            dateRule: HolidayDateRule(calendar: .lunar, month: 1, day: 1),
            isCustom: false,
            note: "含除夕及调休放假区间"
        ),
        ChinaHoliday(
            id: "qingming",
            name: "清明节",
            dateRule: HolidayDateRule(
                calendar: .solar,
                month: 4,
                day: nil,
                specialDescription: "清明节气"
            ),
            isCustom: false,
            note: "通常在 4 月 4 日或 5 日附近"
        ),
        ChinaHoliday(
            id: "labor-day",
            name: "劳动节",
            dateRule: HolidayDateRule(calendar: .solar, month: 5, day: 1),
            isCustom: false,
            note: "五一劳动节"
        ),
        ChinaHoliday(
            id: "dragon-boat",
            name: "端午节",
            dateRule: HolidayDateRule(calendar: .lunar, month: 5, day: 5),
            isCustom: false,
            note: "端阳节"
        ),
        ChinaHoliday(
            id: "mid-autumn",
            name: "中秋节",
            dateRule: HolidayDateRule(calendar: .lunar, month: 8, day: 15),
            isCustom: false,
            note: "团圆节"
        ),
        ChinaHoliday(
            id: "national-day",
            name: "国庆节",
            dateRule: HolidayDateRule(calendar: .solar, month: 10, day: 1),
            isCustom: false,
            note: "中华人民共和国国庆节"
        )
    ]

    static let defaultSelectedIDs: Set<String> = [
        "new-year",
        "spring-festival",
        "qingming",
        "labor-day",
        "dragon-boat",
        "mid-autumn",
        "national-day"
    ]

    static let defaultSpanDaysByID: [String: Int] = [
        "new-year": 3,
        "spring-festival": 8,
        "qingming": 3,
        "labor-day": 5,
        "dragon-boat": 3,
        "mid-autumn": 3,
        "national-day": 7
    ]
}

struct HolidayConfiguration: Codable, Equatable {
    var selectedHolidayIDs: [String]
    var customHolidays: [ChinaHoliday]
    var holidaySpanDaysByID: [String: Int]
    var makeupWorkDateKeys: [String]
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case selectedHolidayIDs
        case customHolidays
        case holidaySpanDaysByID
        case makeupWorkDateKeys
        case updatedAt
    }

    init(
        selectedHolidayIDs: [String],
        customHolidays: [ChinaHoliday],
        holidaySpanDaysByID: [String: Int],
        makeupWorkDateKeys: [String],
        updatedAt: Date
    ) {
        self.selectedHolidayIDs = selectedHolidayIDs
        self.customHolidays = customHolidays
        self.holidaySpanDaysByID = holidaySpanDaysByID
        self.makeupWorkDateKeys = makeupWorkDateKeys
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedHolidayIDs = try container.decode([String].self, forKey: .selectedHolidayIDs)
        customHolidays = try container.decode([ChinaHoliday].self, forKey: .customHolidays)
        holidaySpanDaysByID = try container.decodeIfPresent([String: Int].self, forKey: .holidaySpanDaysByID) ?? [:]
        makeupWorkDateKeys = try container.decodeIfPresent([String].self, forKey: .makeupWorkDateKeys) ?? []
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
