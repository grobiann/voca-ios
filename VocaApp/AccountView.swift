import SwiftUI
struct AccountView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 18) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 56)).foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 6) { Text("나만의 단어 생활").font(.title3.bold()); Text("이 기기에서 학습 중").font(.subheadline).foregroundStyle(.secondary) }
                    }.padding(.vertical, 16)
                }
                Section("학습 설정") {
                    LabeledContent("학습 언어", value: "일본어")
                    LabeledContent("모국어", value: "한국어")
                    Toggle("카드 햅틱 피드백", isOn: $store.haptics).onChange(of: store.haptics) { _, value in UserDefaults.standard.set(value, forKey: "haptics") }
                    LabeledContent("완료 기준", value: "양방향 정답")
                }
                Section {
                    LabeledContent("로그인", value: "연결 없이 사용 중")
                    LabeledContent("구독", value: "개인용 · 무료")
                } header: { Text("계정") } footer: { Text("로그인과 구독은 아직 제공하지 않습니다. 카드와 학습 기록은 이 기기에 저장됩니다.") }
                Section("앱 정보") {
                    LabeledContent("voca-ios", value: "1.0")
                    Text("매일 한 장, 조금 더 가까운 일본어.").foregroundStyle(.secondary)
                }
            }.navigationTitle("계정")
        }
    }
}
