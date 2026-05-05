import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var holidayStore: HolidayStore
    @State private var editorDraft: AlarmDraft?

    var body: some View {
        NavigationStack {
            List {
                if let statusMessage = alarmStore.statusMessage {
                    Section {
                        Label(statusMessage, systemImage: alarmStore.isScheduling ? "clock.arrow.circlepath" : "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if alarmStore.alarms.isEmpty {
                    ContentUnavailableView(
                        "暂无闹钟",
                        systemImage: "alarm",
                        description: Text("添加一个闹钟后，系统会自动跳过你启用的免闹钟节日。")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(alarmStore.alarms) { alarm in
                            AlarmRow(alarm: alarm) {
                                editorDraft = AlarmDraft(alarm: alarm)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await alarmStore.deleteAlarm(alarm)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    editorDraft = AlarmDraft(alarm: alarm)
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } footer: {
                        Text("启用后会用 iOS 26 AlarmKit 预先排入未来 90 天的系统闹钟，节日当天不会排入。")
                    }
                }
            }
            .navigationTitle("闹钟")
            .largeNavigationTitleOnIOS()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorDraft = AlarmDraft()
                    } label: {
                        Label("添加闹钟", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task {
                            await alarmStore.refreshSchedules(
                                skipping: holidayStore.selectedHolidays,
                                spanDaysByID: holidayStore.holidaySpanDaysByID,
                                makeupWorkDateKeys: holidayStore.makeupWorkDateKeys
                            )
                        }
                    } label: {
                        Label("同步闹钟", systemImage: "arrow.clockwise")
                    }
                    .disabled(alarmStore.isScheduling)
                }
            }
            .sheet(item: $editorDraft) { draft in
                AlarmEditorView(initialDraft: draft) { savedDraft in
                    Task {
                        await alarmStore.upsertAlarm(
                            savedDraft,
                            skipping: holidayStore.selectedHolidays,
                            spanDaysByID: holidayStore.holidaySpanDaysByID,
                            makeupWorkDateKeys: holidayStore.makeupWorkDateKeys
                        )
                    }
                }
            }
        }
    }
}

private struct AlarmRow: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var holidayStore: HolidayStore
    let alarm: SmartAlarm
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(alarm.timeText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(alarm.displayTitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(detailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }

            Spacer()

            Toggle(
                "启用",
                isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { enabled in
                        Task {
                            await alarmStore.setAlarm(
                                alarm,
                                enabled: enabled,
                                skipping: holidayStore.selectedHolidays,
                                spanDaysByID: holidayStore.holidaySpanDaysByID,
                                makeupWorkDateKeys: holidayStore.makeupWorkDateKeys
                            )
                        }
                    }
                )
            )
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private var detailText: String {
        var parts = [alarm.repeatText]

        if alarm.skipsSelectedHolidays {
            parts.append("跳过免闹钟节日")
        }

        if let nextFireDate = alarm.nextFireDate {
            parts.append("下次 \(nextFireDate.formatted(date: .abbreviated, time: .shortened))")
        }

        return parts.joined(separator: " · ")
    }
}

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
