import SwiftUI
import VocaCore
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
                    Stepper("학습 풀 크기: \(store.poolSize)개", value: $store.poolSize, in: 1...100)
                    Text("기본 20개 · 1~100개 중 선택할 수 있어요. 모르는 카드는 풀 안에서 반복하고, 같은 단어의 반대 방향은 간격을 두고 보여 줍니다.").font(.caption).foregroundStyle(.secondary)
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
                    NavigationLink("단어 오류 제보함") { WordReportList() }
                    LabeledContent("voca-ios", value: "1.0")
                    Text("매일 한 장, 조금 더 가까운 일본어.").foregroundStyle(.secondary)
                }
            }.navigationTitle("계정")
        }
    }
}

struct WordReportList: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section {
                ForEach((store.archive.wordReports ?? []).reversed()) { report in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(report.word.japanese).font(.headline).textSelection(.enabled)
                        Text("\(report.libraryTitle ?? "내 스택") · \(report.stackTitle)").font(.caption).foregroundStyle(.secondary)
                        Text(report.message)
                        Text(report.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        ShareLink(item: report.shareText) { Label("제보 공유", systemImage: "square.and.arrow.up") }
                    }.padding(.vertical, 6)
                }
                if (store.archive.wordReports ?? []).isEmpty { Text("저장된 제보가 없어요.").foregroundStyle(.secondary) }
            } footer: { Text("제보는 이 기기에 저장됩니다. 공유 버튼으로 내용을 전달할 수 있습니다.") }
        }.navigationTitle("단어 오류 제보함")
    }
}

struct WordReportComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let library: Library?
    let stacks: [Stack]
    @State private var selectedStackID: UUID?
    @State private var selectedWordID: UUID?
    @State private var message = ""
    @State private var query = ""
    private var stack: Stack? { stacks.first { $0.id == selectedStackID } ?? stacks.first }
    private var word: Word? { stack?.words.first { $0.id == selectedWordID } }
    var body: some View {
        Form {
            Section("제보 위치") {
                Text(library?.title ?? "내 스택")
                Picker("스택", selection: $selectedStackID) {
                    ForEach(stacks) { Text($0.title).tag(Optional($0.id)) }
                }.onChange(of: selectedStackID) { _, _ in selectedWordID = nil; query = "" }
            }
            Section("틀린 단어 선택") {
                TextField("일본어 · 한국어 검색", text: $query)
                ForEach((stack?.words ?? []).filter { query.isEmpty || $0.japanese.localizedCaseInsensitiveContains(query) || $0.korean.localizedCaseInsensitiveContains(query) }) { candidate in
                    Button { selectedWordID = candidate.id } label: {
                        HStack {
                            VStack(alignment: .leading) { Text(candidate.japanese); Text(candidate.korean).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            if selectedWordID == candidate.id { Image(systemName: "checkmark.circle.fill") }
                        }
                    }.foregroundStyle(.primary)
                }
            }
            if let word {
                Section("선택한 카드") { Text(word.japanese); Text(word.korean); Text(word.example) }
            }
            Section {
                TextField("틀린 부분이나 올바른 뜻을 적어 주세요", text: $message, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("reportMessage")
                Button("제보 저장") {
                    guard let stack, let word else { return }
                    let report = WordReport(library: library, stack: stack, word: word, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
                    store.archive.wordReports = (store.archive.wordReports ?? []) + [report]
                    store.save()
                    if store.error == nil { dismiss() }
                }.disabled(word == nil || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: { Text("오류 내용") } footer: { Text("기기에 저장되며 자동 전송되지 않습니다. 계정 탭의 제보함에서 공유할 수 있어요.") }
        }.navigationTitle("틀린 단어 제보").onAppear { if selectedStackID == nil { selectedStackID = stacks.first?.id } }
    }
}
