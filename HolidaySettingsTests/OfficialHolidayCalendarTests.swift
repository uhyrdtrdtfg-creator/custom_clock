import XCTest
@testable import HolidaySettings

final class OfficialHolidayCalendarTests: XCTestCase {
    func testOfficialCalendarDataIsValid() {
        XCTAssertTrue(OfficialHolidayCalendar.validate(OfficialHolidayCalendar.schedules))
        XCTAssertEqual(OfficialHolidayCalendar.supportedYearText, "2026")
        XCTAssertEqual(OfficialHolidayCalendar.allMakeupWorkDateKeys.count, 6)
    }

    func testOnlyPublicHolidayTypesAreBuiltIn() {
        let builtInNames = Set(ChinaHoliday.builtIn.map(\.name))
        XCTAssertEqual(builtInNames, ["元旦", "春节", "清明节", "劳动节", "端午节", "中秋节", "国庆节"])
        XCTAssertFalse(builtInNames.contains("元宵节"))
        XCTAssertFalse(builtInNames.contains("七夕节"))
        XCTAssertFalse(builtInNames.contains("重阳节"))
        XCTAssertFalse(builtInNames.contains("腊八节"))
    }

    func testDayCountIsDerivedFromDateRange() {
        let springFestival2026 = OfficialHolidayCalendar.allPeriods.first { $0.id == "2026-spring-festival" }
        XCTAssertEqual(springFestival2026?.dayCount, 9)

        let newYear2026 = OfficialHolidayCalendar.allPeriods.first { $0.id == "2026-new-year" }
        XCTAssertEqual(newYear2026?.dayCount, 3)
    }

    func testDateKeyValidationRejectsMalformedAndOverflowingDates() {
        XCTAssertTrue(OfficialHolidayCalendar.isValidDateKey("2026-02-28"))
        XCTAssertFalse(OfficialHolidayCalendar.isValidDateKey("2026-02-30"))
        XCTAssertFalse(OfficialHolidayCalendar.isValidDateKey("2026-2-28"))
        XCTAssertFalse(OfficialHolidayCalendar.isValidDateKey("2026-00-01"))
        XCTAssertFalse(OfficialHolidayCalendar.isValidDateKey("not-a-date"))
    }

    func testCalendarValidationRejectsInvalidOfficialDateRanges() {
        let invalidSchedule = OfficialHolidayYear(
            year: 2026,
            noticeTitle: "invalid",
            noticeURL: "https://example.invalid",
            periods: [
                OfficialHolidayPeriod(
                    id: "invalid-date",
                    holidayIDs: ["new-year"],
                    name: "无效日期",
                    startDateKey: "2026-02-30",
                    endDateKey: "2026-03-01"
                )
            ],
            makeupWorkdays: []
        )

        XCTAssertFalse(OfficialHolidayCalendar.validate([invalidSchedule]))
    }

    func testCalendarValidationRejectsUnknownHolidayIDs() {
        let invalidSchedule = OfficialHolidayYear(
            year: 2026,
            noticeTitle: "invalid",
            noticeURL: "https://example.invalid",
            periods: [
                OfficialHolidayPeriod(
                    id: "unknown-holiday",
                    holidayIDs: ["lantern-festival"],
                    name: "元宵节",
                    startDateKey: "2026-03-03",
                    endDateKey: "2026-03-03"
                )
            ],
            makeupWorkdays: []
        )

        XCTAssertFalse(OfficialHolidayCalendar.validate([invalidSchedule]))
    }
}
