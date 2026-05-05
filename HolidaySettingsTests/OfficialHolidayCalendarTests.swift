import XCTest
@testable import HolidaySettings

final class OfficialHolidayCalendarTests: XCTestCase {
    func testOfficialCalendarDataIsValid() {
        XCTAssertTrue(OfficialHolidayCalendar.validate(OfficialHolidayCalendar.schedules))
        XCTAssertEqual(OfficialHolidayCalendar.supportedYearText, "2025-2026")
        XCTAssertEqual(OfficialHolidayCalendar.allMakeupWorkDateKeys.count, 11)
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

        let newYear2025 = OfficialHolidayCalendar.allPeriods.first { $0.id == "2025-new-year" }
        XCTAssertEqual(newYear2025?.dayCount, 1)
    }
}
