import XCTest
@testable import HolidaySettings

final class HolidayDateResolverTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    func testResolverUsesOfficialSpringFestivalRange() throws {
        let resolver = HolidayDateResolver(calendar: calendar)
        let occurrences = resolver.occurrences(
            for: ChinaHoliday.builtIn,
            from: try makeDate("2026-02-14"),
            through: try makeDate("2026-02-24")
        )
        let keys = Set(occurrences.map(\.dateKey))

        XCTAssertFalse(keys.contains("2026-02-14"))
        XCTAssertTrue(keys.contains("2026-02-15"))
        XCTAssertTrue(keys.contains("2026-02-23"))
        XCTAssertFalse(keys.contains("2026-02-24"))
    }

    func testSchedulerSkipsOfficialHolidayButAllowsMakeupOverride() throws {
        let alarm = SmartAlarm(
            hour: 8,
            minute: 0,
            repeatWeekdays: Set(AlarmWeekday.allCases),
            skipsSelectedHolidays: true,
            isEnabled: true
        )
        let now = try makeDate("2025-12-31")

        let skippedPlan = AlarmKitScheduler.makePlan(
            for: alarm,
            skipping: ChinaHoliday.builtIn,
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(skippedPlan.fireDates.contains(try makeDate("2026-01-01", hour: 8)))

        let makeupPlan = AlarmKitScheduler.makePlan(
            for: alarm,
            skipping: ChinaHoliday.builtIn,
            makeupWorkDateKeys: ["2026-01-01"],
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(makeupPlan.fireDates.contains(try makeDate("2026-01-01", hour: 8)))
    }

    func testSchedulerCoverageReflectsOccurrenceLimit() throws {
        let alarm = SmartAlarm(
            hour: 8,
            minute: 0,
            repeatWeekdays: Set(AlarmWeekday.allCases),
            skipsSelectedHolidays: false,
            isEnabled: true
        )
        let now = try makeDate("2026-01-01")
        let plan = AlarmKitScheduler.makePlan(for: alarm, skipping: [], now: now, calendar: calendar)

        XCTAssertEqual(plan.fireDates.count, AlarmKitScheduler.maxScheduledOccurrences)
        XCTAssertEqual(calendar.dateComponents([.day], from: now, to: plan.coverageThrough).day, 63)
    }

    private func makeDate(_ dateKey: String, hour: Int = 0, minute: Int = 0) throws -> Date {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        let date = calendar.date(from: DateComponents(
            year: parts[safe: 0],
            month: parts[safe: 1],
            day: parts[safe: 2],
            hour: hour,
            minute: minute
        ))
        return try XCTUnwrap(date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
