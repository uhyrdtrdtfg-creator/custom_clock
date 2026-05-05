import SwiftUI

struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AlarmDraft

    let onSave: (AlarmDraft) -> Void

    init(initialDraft: AlarmDraft, onSave: @escaping (AlarmDraft) -> Void) {
        self._draft = State(initialValue: initialDraft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("时间", selection: $draft.time, displayedComponents: .hourAndMinute)
                        .wheelDatePickerOnIOS()
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Section("名称") {
                    TextField("闹钟名称", text: $draft.title)
                }

                Section("重复") {
                    weekdayGrid
                    repeatPresetButtons
                }

                Section {
                    Toggle("跳过已启用的中国节日", isOn: $draft.skipsSelectedHolidays)
                    Toggle("保存后启用", isOn: $draft.isEnabled)
                } footer: {
                    Text("节日跳过通过预排未来日期实现；修改节日后，闹钟会重新同步。")
                }
            }
            .navigationTitle(draft.alarmID == nil ? "添加闹钟" : "编辑闹钟")
            .inlineNavigationTitleOnIOS()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    private var weekdayGrid: some View {
        HStack(spacing: 8) {
            ForEach(AlarmWeekday.allCases) { weekday in
                Button {
                    toggle(weekday)
                } label: {
                    Text(weekday.shortTitle)
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(draft.repeatWeekdays.contains(weekday) ? .white : .primary)
                        .background(
                            draft.repeatWeekdays.contains(weekday) ? Color.accentColor : Color.secondary.opacity(0.14),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }

    private var repeatPresetButtons: some View {
        HStack(spacing: 10) {
            Button("工作日") {
                draft.repeatWeekdays = AlarmWeekday.workdays
            }
            .buttonStyle(.bordered)

            Button("周末") {
                draft.repeatWeekdays = AlarmWeekday.weekend
            }
            .buttonStyle(.bordered)

            Button("每天") {
                draft.repeatWeekdays = Set(AlarmWeekday.allCases)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ weekday: AlarmWeekday) {
        if draft.repeatWeekdays.contains(weekday) {
            draft.repeatWeekdays.remove(weekday)
        } else {
            draft.repeatWeekdays.insert(weekday)
        }
    }
}

private extension View {
    @ViewBuilder
    func wheelDatePickerOnIOS() -> some View {
        #if os(iOS)
        self.datePickerStyle(.wheel)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineNavigationTitleOnIOS() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
