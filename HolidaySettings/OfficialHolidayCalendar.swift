import Foundation

struct OfficialHolidayPeriod: Identifiable, Hashable {
    let id: String
    let holidayIDs: Set<String>
    let name: String
    let startDateKey: String
    let endDateKey: String
    let dayCount: Int

    var displayText: String {
        startDateKey == endDateKey ? startDateKey : "\(startDateKey) 至 \(endDateKey)"
    }

    var primaryHolidayID: String {
        holidayIDs.sorted().first ?? id
    }

    func contains(_ dateKey: String) -> Bool {
        startDateKey <= dateKey && dateKey <= endDateKey
    }
}

struct OfficialMakeupWorkday: Identifiable, Hashable {
    var id: String { dateKey }
    let dateKey: String
    let reason: String
}

struct OfficialHolidayYear: Identifiable, Hashable {
    var id: Int { year }
    let year: Int
    let noticeTitle: String
    let noticeURL: String
    let periods: [OfficialHolidayPeriod]
    let makeupWorkdays: [OfficialMakeupWorkday]
}

enum OfficialHolidayCalendar {
    static let schedules: [OfficialHolidayYear] = [
        OfficialHolidayYear(
            year: 2025,
            noticeTitle: "国务院办公厅关于2025年部分节假日安排的通知",
            noticeURL: "https://www.gov.cn/zhengce/content/202411/content_6986382.htm",
            periods: [
                OfficialHolidayPeriod(
                    id: "2025-new-year",
                    holidayIDs: ["new-year"],
                    name: "元旦",
                    startDateKey: "2025-01-01",
                    endDateKey: "2025-01-01",
                    dayCount: 1
                ),
                OfficialHolidayPeriod(
                    id: "2025-spring-festival",
                    holidayIDs: ["spring-festival"],
                    name: "春节",
                    startDateKey: "2025-01-28",
                    endDateKey: "2025-02-04",
                    dayCount: 8
                ),
                OfficialHolidayPeriod(
                    id: "2025-qingming",
                    holidayIDs: ["qingming"],
                    name: "清明节",
                    startDateKey: "2025-04-04",
                    endDateKey: "2025-04-06",
                    dayCount: 3
                ),
                OfficialHolidayPeriod(
                    id: "2025-labor-day",
                    holidayIDs: ["labor-day"],
                    name: "劳动节",
                    startDateKey: "2025-05-01",
                    endDateKey: "2025-05-05",
                    dayCount: 5
                ),
                OfficialHolidayPeriod(
                    id: "2025-dragon-boat",
                    holidayIDs: ["dragon-boat"],
                    name: "端午节",
                    startDateKey: "2025-05-31",
                    endDateKey: "2025-06-02",
                    dayCount: 3
                ),
                OfficialHolidayPeriod(
                    id: "2025-national-day-mid-autumn",
                    holidayIDs: ["national-day", "mid-autumn"],
                    name: "国庆节、中秋节",
                    startDateKey: "2025-10-01",
                    endDateKey: "2025-10-08",
                    dayCount: 8
                )
            ],
            makeupWorkdays: [
                OfficialMakeupWorkday(dateKey: "2025-01-26", reason: "春节调休"),
                OfficialMakeupWorkday(dateKey: "2025-02-08", reason: "春节调休"),
                OfficialMakeupWorkday(dateKey: "2025-04-27", reason: "劳动节调休"),
                OfficialMakeupWorkday(dateKey: "2025-09-28", reason: "国庆节、中秋节调休"),
                OfficialMakeupWorkday(dateKey: "2025-10-11", reason: "国庆节、中秋节调休")
            ]
        ),
        OfficialHolidayYear(
            year: 2026,
            noticeTitle: "国务院办公厅关于2026年部分节假日安排的通知",
            noticeURL: "https://www.gov.cn/zhengce/content/202511/content_7047090.htm",
            periods: [
                OfficialHolidayPeriod(
                    id: "2026-new-year",
                    holidayIDs: ["new-year"],
                    name: "元旦",
                    startDateKey: "2026-01-01",
                    endDateKey: "2026-01-03",
                    dayCount: 3
                ),
                OfficialHolidayPeriod(
                    id: "2026-spring-festival",
                    holidayIDs: ["spring-festival"],
                    name: "春节",
                    startDateKey: "2026-02-15",
                    endDateKey: "2026-02-23",
                    dayCount: 9
                ),
                OfficialHolidayPeriod(
                    id: "2026-qingming",
                    holidayIDs: ["qingming"],
                    name: "清明节",
                    startDateKey: "2026-04-04",
                    endDateKey: "2026-04-06",
                    dayCount: 3
                ),
                OfficialHolidayPeriod(
                    id: "2026-labor-day",
                    holidayIDs: ["labor-day"],
                    name: "劳动节",
                    startDateKey: "2026-05-01",
                    endDateKey: "2026-05-05",
                    dayCount: 5
                ),
                OfficialHolidayPeriod(
                    id: "2026-dragon-boat",
                    holidayIDs: ["dragon-boat"],
                    name: "端午节",
                    startDateKey: "2026-06-19",
                    endDateKey: "2026-06-21",
                    dayCount: 3
                ),
                OfficialHolidayPeriod(
                    id: "2026-mid-autumn",
                    holidayIDs: ["mid-autumn"],
                    name: "中秋节",
                    startDateKey: "2026-09-25",
                    endDateKey: "2026-09-27",
                    dayCount: 3
                ),
                OfficialHolidayPeriod(
                    id: "2026-national-day",
                    holidayIDs: ["national-day"],
                    name: "国庆节",
                    startDateKey: "2026-10-01",
                    endDateKey: "2026-10-07",
                    dayCount: 7
                )
            ],
            makeupWorkdays: [
                OfficialMakeupWorkday(dateKey: "2026-01-04", reason: "元旦调休"),
                OfficialMakeupWorkday(dateKey: "2026-02-14", reason: "春节调休"),
                OfficialMakeupWorkday(dateKey: "2026-02-28", reason: "春节调休"),
                OfficialMakeupWorkday(dateKey: "2026-05-09", reason: "劳动节调休"),
                OfficialMakeupWorkday(dateKey: "2026-09-20", reason: "国庆节调休"),
                OfficialMakeupWorkday(dateKey: "2026-10-10", reason: "国庆节调休")
            ]
        )
    ]

    static var supportedYearText: String {
        let years = schedules.map(\.year).sorted()
        guard let first = years.first, let last = years.last else { return "暂无官方数据" }
        return first == last ? "\(first)" : "\(first)-\(last)"
    }

    static var allPeriods: [OfficialHolidayPeriod] {
        schedules.flatMap(\.periods)
    }

    static var allMakeupWorkdays: [OfficialMakeupWorkday] {
        schedules.flatMap(\.makeupWorkdays).sorted { $0.dateKey < $1.dateKey }
    }

    static var allMakeupWorkDateKeys: Set<String> {
        Set(allMakeupWorkdays.map(\.dateKey))
    }

    static func hasSchedule(forYear year: Int) -> Bool {
        schedules.contains { $0.year == year }
    }

    static func year(for dateKey: String) -> Int? {
        Int(dateKey.prefix(4))
    }

    static func periods(containing dateKey: String, matchingHolidayIDs holidayIDs: Set<String>) -> [OfficialHolidayPeriod] {
        guard
            let year = year(for: dateKey),
            let schedule = schedules.first(where: { $0.year == year })
        else {
            return []
        }

        return schedule.periods.filter { period in
            period.contains(dateKey) && !period.holidayIDs.isDisjoint(with: holidayIDs)
        }
    }
}
