import SwiftUI
import UserNotifications

extension Notification.Name {
    static let finishMicroReview = Notification.Name("voca.finishMicroReview")
    static let openMicroReview = Notification.Name("voca.openMicroReview")
}

final class VocaNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var pendingMicroReview = false
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-notification-open") { Self.pendingMicroReview = true }
        #endif
        return true
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["vocaMicroReview"] as? Bool == true else { return }
        await MainActor.run {
            Self.pendingMicroReview = true
            NotificationCenter.default.post(name: .openMicroReview, object: nil)
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main struct VocaApp: App {
    @UIApplicationDelegateAdaptor(VocaNotificationDelegate.self) private var notificationDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore()
    @State private var showMicroReview = false
    @State private var rootReady = false
    @State private var selectedTab = 0
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                LearnView().tabItem { Label("학습", systemImage: "rectangle.on.rectangle.angled") }.tag(0)
                LibraryView().tabItem { Label("라이브러리", systemImage: "books.vertical") }.tag(1)
                AccountView().tabItem { Label("계정", systemImage: "person.crop.circle") }.tag(2)
            }
            .tint(Palette.accent).environment(store)
            .fullScreenCover(isPresented: $showMicroReview) { MicroReviewSessionView().environment(store) }
            .onReceive(NotificationCenter.default.publisher(for: .openMicroReview)) { _ in
                presentPendingMicroReviewIfReady()
            }
            .onReceive(NotificationCenter.default.publisher(for: .finishMicroReview)) { _ in
                selectedTab = 0
            }
            .onAppear {
                rootReady = true
                store.scheduleMicroNotifications()
                presentPendingMicroReviewIfReady()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    store.scheduleMicroNotifications()
                    Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                    presentPendingMicroReviewIfReady()
                }
            }
            .alert("확인이 필요해요", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("확인") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
    private func presentPendingMicroReviewIfReady() {
        guard rootReady, scenePhase == .active, VocaNotificationDelegate.pendingMicroReview, !showMicroReview else { return }
        VocaNotificationDelegate.pendingMicroReview = false
        Task { @MainActor in
            await Task.yield()
            if UIApplication.shared.applicationState == .active {
                showMicroReview = true
            } else {
                VocaNotificationDelegate.pendingMicroReview = true
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 19)
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
