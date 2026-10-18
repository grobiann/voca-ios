import SwiftUI

@main struct VocaApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                LearnView().tabItem { Label("학습", systemImage: "rectangle.on.rectangle.angled") }
                LibraryView().tabItem { Label("라이브러리", systemImage: "books.vertical") }
                AccountView().tabItem { Label("계정", systemImage: "person.crop.circle") }
            }
            .tint(Palette.accent).environment(store)
            .alert("확인이 필요해요", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("확인") { store.error = nil }
            } message: { Text(store.error ?? "") }
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
