import Foundation

struct OfficialHolidayPeriod: Identifiable, Hashable, Codable {
    let id: String
    let holidayIDs: Set<String>
    let name: String
    let startDateKey: String
    let endDateKey: String

    var dayCount: Int {
        OfficialHolidayCalendar.dayCount(from: startDateKey, through: endDateKey)
    }

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

struct OfficialMakeupWorkday: Identifiable, Hashable, Codable {
    var id: String { dateKey }
    let dateKey: String
    let reason: String
}

struct OfficialHolidayYear: Identifiable, Hashable, Codable {
    var id: Int { year }
    let year: Int
    let noticeTitle: String
    let noticeURL: String
    let periods: [OfficialHolidayPeriod]
    let makeupWorkdays: [OfficialMakeupWorkday]
}

enum OfficialHolidayCalendar {
    static let resourceName = "OfficialHolidayCalendar"

    static let schedules: [OfficialHolidayYear] = {
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([OfficialHolidayYear].self, from: data),
            validate(decoded)
        else {
            return fallbackSchedules
        }

        return decoded
    }()

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

    static var latestHolidayEndDateKey: String? {
        allPeriods.map(\.endDateKey).max()
    }

    static func hasSchedule(forYear year: Int) -> Bool {
        schedules.contains { $0.year == year }
    }

    static func year(for dateKey: String) -> Int? {
        guard isValidDateKey(dateKey) else { return nil }
        return Int(dateKey.prefix(4))
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

    static func coverageNoticeText(now: Date = Date(), horizonDays: Int = 90) -> String? {
        guard
            let latestHolidayEndDateKey,
            let horizonDate = gregorianCalendar.date(byAdding: .day, value: horizonDays, to: now)
        else {
            return nil
        }

        let horizonDateKey = dateKey(for: horizonDate)
        guard horizonDateKey > latestHolidayEndDateKey else { return nil }

        return "官方数据已覆盖到 \(latestHolidayEndDateKey)。国务院发布下一年度安排后，请更新内置数据。"
    }

    static func dayCount(from startDateKey: String, through endDateKey: String) -> Int {
        guard
            let startDate = date(from: startDateKey),
            let endDate = date(from: endDateKey),
            let days = gregorianCalendar.dateComponents([.day], from: startDate, to: endDate).day
        else {
            return 1
        }

        return max(1, days + 1)
    }

    static func validate(_ schedules: [OfficialHolidayYear]) -> Bool {
        var yearIDs: Set<Int> = []
        var periodIDs: Set<String> = []
        var makeupDateKeys: Set<String> = []
        let supportedHolidayIDs = Set(ChinaHoliday.builtIn.map(\.id))

        for schedule in schedules {
            guard yearIDs.insert(schedule.year).inserted else { return false }

            for period in schedule.periods {
                guard
                    periodIDs.insert(period.id).inserted,
                    period.holidayIDs.isEmpty == false,
                    period.holidayIDs.isSubset(of: supportedHolidayIDs),
                    isValidDateKey(period.startDateKey),
                    isValidDateKey(period.endDateKey),
                    period.startDateKey <= period.endDateKey
                else {
                    return false
                }
            }

            for workday in schedule.makeupWorkdays {
                guard
                    isValidDateKey(workday.dateKey),
                    makeupDateKeys.insert(workday.dateKey).inserted
                else {
                    return false
                }
            }
        }

        return true
    }

    static func isValidDateKey(_ dateKey: String) -> Bool {
        date(from: dateKey) != nil
    }

    static func dateKey(for date: Date, calendar: Calendar = gregorianCalendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private static func date(from dateKey: String) -> Date? {
        guard dateKey.count == 10 else { return nil }

        let parts = dateKey.split(separator: "-")
        guard
            parts.count == 3,
            parts[0].count == 4,
            parts[1].count == 2,
            parts[2].count == 2,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        guard
            let date = gregorianCalendar.date(from: DateComponents(year: year, month: month, day: day))
        else {
            return nil
        }

        let components = gregorianCalendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else {
            return nil
        }

        return date
    }

    private static let fallbackSchedules: [OfficialHolidayYear] = [
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
                    endDateKey: "2026-01-03"
                ),
                OfficialHolidayPeriod(
                    id: "2026-spring-festival",
                    holidayIDs: ["spring-festival"],
                    name: "春节",
                    startDateKey: "2026-02-15",
                    endDateKey: "2026-02-23"
                ),
                OfficialHolidayPeriod(
                    id: "2026-qingming",
                    holidayIDs: ["qingming"],
                    name: "清明节",
                    startDateKey: "2026-04-04",
                    endDateKey: "2026-04-06"
                ),
                OfficialHolidayPeriod(
                    id: "2026-labor-day",
                    holidayIDs: ["labor-day"],
                    name: "劳动节",
                    startDateKey: "2026-05-01",
                    endDateKey: "2026-05-05"
                ),
                OfficialHolidayPeriod(
                    id: "2026-dragon-boat",
                    holidayIDs: ["dragon-boat"],
                    name: "端午节",
                    startDateKey: "2026-06-19",
                    endDateKey: "2026-06-21"
                ),
                OfficialHolidayPeriod(
                    id: "2026-mid-autumn",
                    holidayIDs: ["mid-autumn"],
                    name: "中秋节",
                    startDateKey: "2026-09-25",
                    endDateKey: "2026-09-27"
                ),
                OfficialHolidayPeriod(
                    id: "2026-national-day",
                    holidayIDs: ["national-day"],
                    name: "国庆节",
                    startDateKey: "2026-10-01",
                    endDateKey: "2026-10-07"
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
}
