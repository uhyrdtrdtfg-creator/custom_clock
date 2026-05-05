import SwiftUI

struct CustomHolidayEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomHolidayDraft

    let onSave: (CustomHolidayDraft) -> Void

    init(initialDraft: CustomHolidayDraft, onSave: @escaping (CustomHolidayDraft) -> Void) {
        self._draft = State(initialValue: initialDraft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("节日名称", text: $draft.name)
                }

                Section("日期") {
                    Picker("历法", selection: $draft.calendar) {
                        ForEach(HolidayCalendarKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("月份", selection: $draft.month) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }

                    Picker("日期", selection: $draft.day) {
                        ForEach(1...maximumDay, id: \.self) { day in
                            Text("\(day)日").tag(day)
                        }
                    }
                }

                Section("备注") {
                    TextField("可选", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(draft.holidayID == nil ? "添加节日" : "编辑节日")
            .inlineNavigationTitleOnIOS()
            .onChange(of: draft.calendar) {
                clampDay()
            }
            .onChange(of: draft.month) {
                clampDay()
            }
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

    private var maximumDay: Int {
        if draft.calendar == .lunar {
            return 30
        }

        switch draft.month {
        case 2:
            return 29
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }

    private func clampDay() {
        draft.day = min(draft.day, maximumDay)
    }
}

private extension View {
    @ViewBuilder
    func inlineNavigationTitleOnIOS() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
