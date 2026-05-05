import Foundation
import Combine

@MainActor
final class HolidayStore: ObservableObject {
    @Published private(set) var builtInHolidays: [ChinaHoliday]
    @Published var customHolidays: [ChinaHoliday] {
        didSet { persist() }
    }

    @Published var selectedHolidayIDs: Set<String> {
        didSet { persist() }
    }
    @Published var holidaySpanDaysByID: [String: Int] {
        didSet { persist() }
    }
    @Published var makeupWorkDateKeys: Set<String> {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let storageKey = "cn.holiday.settings.configuration.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.builtInHolidays = ChinaHoliday.builtIn

        if
            let data = defaults.data(forKey: storageKey),
            let configuration = try? JSONDecoder.holidayDecoder.decode(HolidayConfiguration.self, from: data)
        {
            self.customHolidays = configuration.customHolidays
            let selectedCustomIDs = Set(configuration.selectedHolidayIDs)
                .intersection(configuration.customHolidays.map(\.id))
            self.selectedHolidayIDs = ChinaHoliday.defaultSelectedIDs.union(selectedCustomIDs)
            self.holidaySpanDaysByID = ChinaHoliday.defaultSpanDaysByID
            self.makeupWorkDateKeys = OfficialHolidayCalendar.allMakeupWorkDateKeys
        } else {
            self.customHolidays = []
            self.selectedHolidayIDs = ChinaHoliday.defaultSelectedIDs
            self.holidaySpanDaysByID = ChinaHoliday.defaultSpanDaysByID
            self.makeupWorkDateKeys = OfficialHolidayCalendar.allMakeupWorkDateKeys
        }
    }

    var allHolidays: [ChinaHoliday] {
        builtInHolidays + customHolidays
    }

    var selectedHolidays: [ChinaHoliday] {
        allHolidays.filter { selectedHolidayIDs.contains($0.id) }
    }

    var selectedBuiltInCount: Int {
        builtInHolidays.filter { selectedHolidayIDs.contains($0.id) }.count
    }

    var selectedCustomCount: Int {
        customHolidays.filter { selectedHolidayIDs.contains($0.id) }.count
    }

    var summaryText: String {
        "已自动接入 \(OfficialHolidayCalendar.supportedYearText) 官方放假调休"
    }

    var officialHolidayPeriods: [OfficialHolidayPeriod] {
        OfficialHolidayCalendar.allPeriods
    }

    var officialMakeupWorkdays: [OfficialMakeupWorkday] {
        OfficialHolidayCalendar.allMakeupWorkdays
    }

    var officialCoverageText: String {
        "官方数据覆盖 \(OfficialHolidayCalendar.supportedYearText)，无需手动选择节假日或补班日。"
    }

    func binding(for holiday: ChinaHoliday) -> Bool {
        selectedHolidayIDs.contains(holiday.id)
    }

    func setHoliday(_ holiday: ChinaHoliday, enabled: Bool) {
        if enabled {
            selectedHolidayIDs.insert(holiday.id)
        } else {
            selectedHolidayIDs.remove(holiday.id)
        }
    }

    func upsertCustomHoliday(_ draft: CustomHolidayDraft) {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let holiday = ChinaHoliday(
            id: draft.holidayID ?? UUID().uuidString,
            name: trimmedName,
            dateRule: HolidayDateRule(
                calendar: draft.calendar,
                month: draft.month,
                day: draft.day
            ),
            isCustom: true,
            note: trimmedNote
        )

        if let existingIndex = customHolidays.firstIndex(where: { $0.id == holiday.id }) {
            customHolidays[existingIndex] = holiday
        } else {
            customHolidays.append(holiday)
            selectedHolidayIDs.insert(holiday.id)
        }
    }

    func deleteCustomHoliday(_ holiday: ChinaHoliday) {
        customHolidays.removeAll { $0.id == holiday.id }
        selectedHolidayIDs.remove(holiday.id)
        holidaySpanDaysByID.removeValue(forKey: holiday.id)
    }

    func resetToRecommended() {
        customHolidays = []
        selectedHolidayIDs = ChinaHoliday.defaultSelectedIDs
        holidaySpanDaysByID = ChinaHoliday.defaultSpanDaysByID
        makeupWorkDateKeys = OfficialHolidayCalendar.allMakeupWorkDateKeys
    }

    func holidaySpanDays(for holiday: ChinaHoliday) -> Int {
        holidaySpanDaysByID[holiday.id] ?? 1
    }

    func setHolidaySpanDays(for holiday: ChinaHoliday, days: Int) {
        holidaySpanDaysByID[holiday.id] = max(1, min(15, days))
    }

    func addMakeupWorkDate(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        makeupWorkDateKeys.insert(Self.makeDateKey(for: date, calendar: calendar))
    }

    func removeMakeupWorkDateKey(_ key: String) {
        makeupWorkDateKeys.remove(key)
    }

    var sortedMakeupWorkDateKeys: [String] {
        makeupWorkDateKeys.sorted()
    }

    func exportJSONString() -> String {
        let configuration = HolidayConfiguration(
            selectedHolidayIDs: selectedHolidayIDs.sorted(),
            customHolidays: customHolidays,
            holidaySpanDaysByID: holidaySpanDaysByID,
            makeupWorkDateKeys: makeupWorkDateKeys.sorted(),
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder.holidayEncoder.encode(configuration) else {
            return "{}"
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func persist() {
        let configuration = HolidayConfiguration(
            selectedHolidayIDs: selectedHolidayIDs.sorted(),
            customHolidays: customHolidays,
            holidaySpanDaysByID: holidaySpanDaysByID,
            makeupWorkDateKeys: makeupWorkDateKeys.sorted(),
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder.holidayEncoder.encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func makeDateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

struct CustomHolidayDraft: Equatable, Identifiable {
    let id: UUID
    var holidayID: String?
    var name: String
    var calendar: HolidayCalendarKind
    var month: Int
    var day: Int
    var note: String

    init(holiday: ChinaHoliday? = nil) {
        self.id = UUID()
        self.holidayID = holiday?.id
        self.name = holiday?.name ?? ""
        self.calendar = holiday?.dateRule.calendar ?? .lunar
        self.month = holiday?.dateRule.month ?? 1
        self.day = holiday?.dateRule.day ?? 1
        self.note = holiday?.note ?? ""
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension JSONEncoder {
    static var holidayEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var holidayDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
