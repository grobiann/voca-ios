import SwiftUI
import UserNotifications
import AlarmKit

@main struct VocaApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                LearnView().tabItem { Label("학습", systemImage: "rectangle.on.rectangle.angled") }
                LibraryView().tabItem { Label("라이브러리", systemImage: "books.vertical") }
                AccountView().tabItem { Label("설정", systemImage: "gearshape") }
            }
            .tint(Palette.accent).environment(store)
            .task {
                await store.refreshPublicDirectory()
                await RetiredReminderCleanup.run()
            }
            .alert("확인이 필요해요", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("확인") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

// Upgrade-only cleanup. Never requests permission or schedules notifications/alarms.
// Keep retrying on launch so a transient system failure does not leave old alarms active.
@MainActor private enum RetiredReminderCleanup {
    static func run() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            guard manager.authorizationState == .authorized else { return }
            guard let alarms = try? manager.alarms else { return }
            for alarm in alarms where alarm.id.uuidString.lowercased().hasPrefix("13300000-0000-4000-") {
                try? manager.cancel(id: alarm.id)
            }
        }
    }
}

enum Palette {
    static let accent = Color(red: 0.18, green: 0.37, blue: 0.30)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let orange = Color(red: 0.82, green: 0.36, blue: 0.20)
}
struct PrimaryButton: ButtonStyle {
    var height: CGFloat? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).lineLimit(1).frame(maxWidth: .infinity)
            .frame(height: height ?? 24).padding(.vertical, height == nil ? 19 : 0)
            .foregroundStyle(.white).background(Palette.accent, in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
struct EmptyState: View {
    var icon: String; var title: String; var message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Palette.accent)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(32)
    }
}
