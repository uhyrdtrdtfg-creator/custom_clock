import Foundation

struct HolidayOccurrence: Identifiable, Hashable {
    var id: String { "\(dateKey)-\(holidayID)" }
    let holidayID: String
    let holidayName: String
    let date: Date
    let dateKey: String
}

struct HolidayDateResolver {
    private var calendar: Calendar
    private var chineseCalendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        var localCalendar = calendar
        localCalendar.timeZone = calendar.timeZone
        self.calendar = localCalendar

        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.timeZone = calendar.timeZone
        self.chineseCalendar = lunarCalendar
    }

    func occurrences(
        for holidays: [ChinaHoliday],
        from startDate: Date,
        through endDate: Date,
        spanDaysByID: [String: Int] = [:]
    ) -> [HolidayOccurrence] {
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        guard startDay <= endDay else { return [] }

        var occurrences: [HolidayOccurrence] = []
        var date = startDay
        let builtInHolidays = holidays.filter { !$0.isCustom }
        let officialHolidayIDs = Set(holidays.filter { !$0.isCustom }.map(\.id))
        let customHolidays = holidays.filter(\.isCustom)

        while date <= endDay {
            let currentDateKey = dateKey(for: date)
            let hasOfficialSchedule: Bool
            if let year = OfficialHolidayCalendar.year(for: currentDateKey) {
                hasOfficialSchedule = OfficialHolidayCalendar.hasSchedule(forYear: year)
            } else {
                hasOfficialSchedule = false
            }

            if hasOfficialSchedule {
                let officialPeriods = OfficialHolidayCalendar.periods(
                    containing: currentDateKey,
                    matchingHolidayIDs: officialHolidayIDs
                )

                for period in officialPeriods {
                    occurrences.append(
                        HolidayOccurrence(
                            holidayID: period.primaryHolidayID,
                            holidayName: period.name,
                            date: date,
                            dateKey: currentDateKey
                        )
                    )
                }
            } else {
                for holiday in builtInHolidays where matches(holiday, on: date, spanDaysByID: spanDaysByID) {
                    occurrences.append(
                        HolidayOccurrence(
                            holidayID: holiday.id,
                            holidayName: holiday.name,
                            date: date,
                            dateKey: currentDateKey
                        )
                    )
                }
            }

            for holiday in customHolidays where matches(holiday, on: date, spanDaysByID: spanDaysByID) {
                occurrences.append(
                    HolidayOccurrence(
                        holidayID: holiday.id,
                        holidayName: holiday.name,
                        date: date,
                        dateKey: currentDateKey
                    )
                )
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDay
        }

        return occurrences
    }

    func occurrenceNamesByDate(
        for holidays: [ChinaHoliday],
        from startDate: Date,
        through endDate: Date,
        spanDaysByID: [String: Int] = [:]
    ) -> [String: [String]] {
        Dictionary(
            grouping: occurrences(
                for: holidays,
                from: startDate,
                through: endDate,
                spanDaysByID: spanDaysByID
            ),
            by: \.dateKey
        )
            .mapValues { $0.map(\.holidayName) }
    }

    func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func matches(_ holiday: ChinaHoliday, on date: Date, spanDaysByID: [String: Int]) -> Bool {
        let currentDateKey = dateKey(for: date)
        if
            !holiday.isCustom,
            let year = OfficialHolidayCalendar.year(for: currentDateKey),
            OfficialHolidayCalendar.hasSchedule(forYear: year)
        {
            return OfficialHolidayCalendar.periods(
                containing: currentDateKey,
                matchingHolidayIDs: [holiday.id]
            )
            .isEmpty == false
        }

        let spanDays = max(1, spanDaysByID[holiday.id] ?? 1)
        if !holiday.isCustom && holiday.id == "spring-festival" {
            return matchesSpringFestivalFallback(on: date, spanDays: spanDays)
        }

        guard spanDays > 1 else {
            return matchesSingleDay(holiday, on: date)
        }

        for offset in 0..<spanDays {
            guard let anchorDate = calendar.date(byAdding: .day, value: -offset, to: date) else {
                continue
            }
            if matchesSingleDay(holiday, on: anchorDate) {
                return true
            }
        }

        return false
    }

    private func matchesSpringFestivalFallback(on date: Date, spanDays: Int) -> Bool {
        if isChineseNewYearsEve(on: date) {
            return true
        }

        let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
        guard
            components.month == 1,
            let day = components.day,
            components.isLeapMonth != true
        else {
            return false
        }

        return (1...max(1, spanDays - 1)).contains(day)
    }

    private func matchesSingleDay(_ holiday: ChinaHoliday, on date: Date) -> Bool {
        if holiday.id == "qingming" {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return false
            }
            return month == 4 && day == qingmingDay(for: year)
        }

        if holiday.id == "new-years-eve" {
            return isChineseNewYearsEve(on: date)
        }

        switch holiday.dateRule.calendar {
        case .solar:
            guard let expectedDay = holiday.dateRule.day else { return false }
            let components = calendar.dateComponents([.month, .day], from: date)
            return components.month == holiday.dateRule.month && components.day == expectedDay
        case .lunar:
            guard let expectedDay = holiday.dateRule.day else { return false }
            let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
            return components.month == holiday.dateRule.month
                && components.day == expectedDay
                && components.isLeapMonth != true
        }
    }

    private func qingmingDay(for year: Int) -> Int {
        let shortYear = Double(year % 100)
        let centuryConstant = (year >= 2000) ? 4.81 : 5.59
        return Int(shortYear * 0.2422 + centuryConstant) - Int(shortYear / 4)
    }

    private func isChineseNewYearsEve(on date: Date) -> Bool {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else {
            return false
        }
        let nextComponents = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: nextDay)
        return nextComponents.month == 1
            && nextComponents.day == 1
            && nextComponents.isLeapMonth != true
    }
}
