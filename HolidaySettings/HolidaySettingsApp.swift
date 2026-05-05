import SwiftUI

@main
struct HolidaySettingsApp: App {
    @StateObject private var holidayStore = HolidayStore()
    @StateObject private var alarmStore = AlarmStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(holidayStore)
                .environmentObject(alarmStore)
        }
    }
}
