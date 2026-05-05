import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HolidayStore
    @EnvironmentObject private var alarmStore: AlarmStore

    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("闹钟", systemImage: "alarm")
                }

            HolidaySettingsView()
                .tabItem {
                    Label("法定节假日", systemImage: "calendar")
                }
        }
        .onChange(of: store.selectedHolidayIDs) {
            Task {
                await alarmStore.refreshSchedules(
                    skipping: store.selectedHolidays,
                    spanDaysByID: store.holidaySpanDaysByID,
                    makeupWorkDateKeys: store.makeupWorkDateKeys
                )
            }
        }
        .onChange(of: store.customHolidays) {
            Task {
                await alarmStore.refreshSchedules(
                    skipping: store.selectedHolidays,
                    spanDaysByID: store.holidaySpanDaysByID,
                    makeupWorkDateKeys: store.makeupWorkDateKeys
                )
            }
        }
        .onChange(of: store.holidaySpanDaysByID) {
            Task {
                await alarmStore.refreshSchedules(
                    skipping: store.selectedHolidays,
                    spanDaysByID: store.holidaySpanDaysByID,
                    makeupWorkDateKeys: store.makeupWorkDateKeys
                )
            }
        }
        .onChange(of: store.makeupWorkDateKeys) {
            Task {
                await alarmStore.refreshSchedules(
                    skipping: store.selectedHolidays,
                    spanDaysByID: store.holidaySpanDaysByID,
                    makeupWorkDateKeys: store.makeupWorkDateKeys
                )
            }
        }
    }
}

private struct HolidaySettingsView: View {
    @EnvironmentObject private var store: HolidayStore
    @State private var editorDraft: CustomHolidayDraft?
    @State private var isShowingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                summarySection
                officialHolidaySection
                officialMakeupWorkdaySection
                customSection
                exportSection
            }
            .navigationTitle("法定节假日")
            .largeNavigationTitleOnIOS()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorDraft = CustomHolidayDraft()
                    } label: {
                        Label("添加节日", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorDraft) { draft in
                CustomHolidayEditor(initialDraft: draft) { savedDraft in
                    store.upsertCustomHoliday(savedDraft)
                }
            }
            .confirmationDialog(
                "恢复推荐设置？",
                isPresented: $isShowingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("恢复推荐设置", role: .destructive) {
                    store.resetToRecommended()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这会清空自定义节日，并恢复国务院公布的法定节假日和补班日期。")
            }
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.summaryText)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }

                HStack(spacing: 12) {
                    SummaryPill(title: "法定节日", value: "\(store.selectedBuiltInCount)")
                    SummaryPill(title: "放假段", value: "\(store.officialHolidayPeriods.count)")
                    SummaryPill(title: "补班日", value: "\(store.officialMakeupWorkdays.count)")
                }

                Text(store.officialCoverageText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var officialHolidaySection: some View {
        Section {
            ForEach(OfficialHolidayCalendar.schedules) { schedule in
                DisclosureGroup("\(schedule.year) 年放假安排") {
                    ForEach(schedule.periods) { period in
                        OfficialHolidayPeriodRow(period: period)
                    }
                }
            }
        } header: {
            Text("国务院放假安排")
        } footer: {
            Text("只保留全体公民放假的节日；元宵节、七夕节、重阳节、腊八节等不再作为内置免闹钟节日。")
        }
    }

    private var customSection: some View {
        Section {
            if store.customHolidays.isEmpty {
                ContentUnavailableView(
                    "暂无自定义节日",
                    systemImage: "calendar.badge.plus",
                    description: Text("添加需要跳过闹钟的纪念日、公司假期或调休日。")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.customHolidays) { holiday in
                    HolidayToggleRow(holiday: holiday)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteCustomHoliday(holiday)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                editorDraft = CustomHolidayDraft(holiday: holiday)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        } header: {
            Text("额外自定义免闹钟节日")
        } footer: {
            Text("官方节假日和补班日已自动处理；这里仅用于你自己的纪念日或公司假期。")
        }
    }

    private var officialMakeupWorkdaySection: some View {
        Section {
            ForEach(store.officialMakeupWorkdays) { workday in
                HStack {
                    Text(workday.dateKey)
                        .font(.body.monospacedDigit())
                    Spacer()
                    Text(workday.reason)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("官方补班日期")
        } footer: {
            Text("补班日会覆盖放假跳过规则，即使落在假期区间也会正常响铃。")
        }
    }

    private var exportSection: some View {
        Section {
            ShareLink(
                item: store.exportJSONString(),
                subject: Text("免闹钟节日设置"),
                message: Text("当前启用的免闹钟节日配置")
            ) {
                Label("导出 JSON 配置", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                Label("恢复官方默认", systemImage: "arrow.counterclockwise")
            }
        }
    }
}

private struct OfficialHolidayPeriodRow: View {
    let period: OfficialHolidayPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(period.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(period.dayCount) 天")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(period.displayText)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct HolidayToggleRow: View {
    @EnvironmentObject private var store: HolidayStore
    let holiday: ChinaHoliday

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { store.binding(for: holiday) },
                set: { store.setHoliday(holiday, enabled: $0) }
            )
        ) {
            VStack(alignment: .leading, spacing: 5) {
                Text(holiday.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(holiday.dateRule.displayText)
                    if !holiday.note.isEmpty {
                        Text(holiday.note)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
                .lineLimit(2)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
        }
    }
}

private struct SummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(HolidayStore(defaults: .init(suiteName: "preview.holiday.settings")!))
        .environmentObject(AlarmStore(defaults: .init(suiteName: "preview.holiday.alarms")!))
}
#endif

private extension View {
    @ViewBuilder
    func largeNavigationTitleOnIOS() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }
}
