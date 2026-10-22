import SwiftUI
import UserNotifications
import AppIntents
import AlarmKit

extension Notification.Name {
    static let finishMicroReview = Notification.Name("voca.finishMicroReview")
    static let openMicroReview = Notification.Name("voca.openMicroReview")
}

final class VocaNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var pendingMicroReview = false
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        VocaShortcuts.updateAppShortcutParameters()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-notification-open") { Self.pendingMicroReview = true }
        #endif
        return true
    }
    // Explicit callbacks keep UIKit's completion on the main actor. The async
    // delegate bridge may resume its completion on a background executor.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                           withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let opensReview = response.notification.request.content.userInfo["vocaMicroReview"] as? Bool == true
        Task { @MainActor in
            defer { completionHandler() }
            guard opensReview else { return }
            Self.pendingMicroReview = true
            NotificationCenter.default.post(name: .openMicroReview, object: nil)
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            completionHandler([.banner])
        }
    }

}

@main struct VocaApp: App {
    @UIApplicationDelegateAdaptor(VocaNotificationDelegate.self) private var notificationDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore()
    @State private var showMicroReview = false
    @State private var rootReady = false
    @State private var selectedTab = 0
    @State private var reviewRouteTask: Task<Void, Never>?
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
                Task { await store.requestMigratedNotificationPermissionIfNeeded() }
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
        guard rootReady, VocaNotificationDelegate.pendingMicroReview else { return }
        if showMicroReview { VocaNotificationDelegate.pendingMicroReview = false; return }
        guard reviewRouteTask == nil else { return }
        reviewRouteTask = Task { @MainActor in
            defer { reviewRouteTask = nil }
            // App Intents may arrive during the foreground transition, before
            // UIApplication and SwiftUI agree that the scene is active.
            for _ in 0..<40 {
                if UIApplication.shared.applicationState == .active {
                    VocaNotificationDelegate.pendingMicroReview = false
                    showMicroReview = true
                    return
                }
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            }
            // Keep the request pending for the next scene activation.
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

public struct OpenMicroReviewIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "1-3-3 학습 시작"
    public static let description = IntentDescription("voca-ios를 열고 1-3-3 단어 확인을 바로 시작합니다.")
    public static let openAppWhenRun = true

    @Parameter(title: "알람 ID") public var alarmID: String?
    public init() {}
    public init(alarmID: String) { self.alarmID = alarmID }
    @MainActor public func perform() async throws -> some IntentResult {
        if #available(iOS 26.0, *), let alarmID, let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        VocaNotificationDelegate.pendingMicroReview = true
        NotificationCenter.default.post(name: .openMicroReview, object: nil)
        return .result()
    }
}

struct VocaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenMicroReviewIntent(),
                    phrases: ["\(.applicationName)에서 단어 확인", "\(.applicationName)에서 1-3-3 시작"],
                    shortTitle: "1-3-3 학습 시작", systemImageName: "rectangle.on.rectangle.angled")
    }
}
