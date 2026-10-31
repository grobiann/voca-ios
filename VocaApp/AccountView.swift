import SwiftUI
import VocaCore
import UserNotifications
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
                    Stepper("단계별 단어: \(store.reviewDepthCount)단계", value: $store.reviewDepthCount, in: store.highestUsedReviewDepth...5)
                    Toggle("앞면에 히라가나 표시", isOn: $store.showReadingOnFront)
                    Toggle("카드 햅틱 피드백", isOn: $store.haptics).onChange(of: store.haptics) { _, value in UserDefaults.standard.set(value, forKey: "haptics") }
                }
                Section("알림") {
                    NavigationLink("단어 확인 알림") {
                        WordReminderSettingsView()
                    }.accessibilityIdentifier("wordReminderSettings")
                }
                Section("앱 정보") {
                    NavigationLink("단어 오류 제보함") { WordReportList() }
                    LabeledContent("voca-ios", value: "1.0")
                }
            }.navigationTitle("계정")
        }
    }
}

struct WordReminderSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var testScheduled = false
    private var settings: MicroReviewSettings { store.microSettings }
    private func binding<Value>(_ keyPath: WritableKeyPath<MicroReviewSettings, Value>) -> Binding<Value> {
        Binding(get: { store.microSettings[keyPath: keyPath] }, set: { value in
            var updated = store.microSettings
            updated[keyPath: keyPath] = value
            store.microSettings = updated
        })
    }
    var body: some View {
        List {
            Section {
                Toggle("단어 확인 알림 켜기", isOn: Binding(
                    get: { settings.enabled },
                    set: { enabled in Task { await store.setMicroEnabled(enabled) } }
                ))
                Picker("알림 간격", selection: binding(\.intervalMinutes)) {
                    ForEach([30, 60, 90, 120, 180], id: \.self) { minutes in Text("\(minutes)분").tag(minutes) }
                }
                Picker("시작 시간", selection: binding(\.startHour)) {
                    ForEach(0..<settings.endHour, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }
                Picker("종료 시간", selection: binding(\.endHour)) {
                    ForEach((settings.startHour + 1)..<25, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }
                Toggle("주말에도 알림", isOn: binding(\.includesWeekends))
            } header: { Text("알림 설정") }
            Section("테스트") {
                Button("5초 후 알림 테스트", systemImage: "bell") {
                    Task { testScheduled = await store.sendMicroTestNotification() }
                }
                if testScheduled {
                    Text("5초 뒤 단어 확인 알림을 받습니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("단어 확인 알림")
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
                        if let corrected = report.correctedKorean {
                            Text("\(report.word.korean) → \(corrected)")
                        } else {
                            Text(report.message)
                        }
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
    let initialWordID: UUID?
    @State private var selectedStackID: UUID?
    @State private var selectedWordID: UUID?
    @State private var correctedKorean = ""
    @State private var query = ""
    init(library: Library?, stacks: [Stack], initialWordID: UUID? = nil) {
        self.library = library
        self.stacks = stacks
        self.initialWordID = initialWordID
        _selectedStackID = State(initialValue: stacks.first?.id)
        _selectedWordID = State(initialValue: initialWordID)
    }
    private var stack: Stack? { stacks.first { $0.id == selectedStackID } ?? stacks.first }
    private var word: Word? { stack?.words.first { $0.id == selectedWordID } }
    private var isInMyCards: Bool {
        guard let stack, let word else { return false }
        return store.archive.stacks.contains { mine in
            (mine.id == stack.id || mine.sourceID == stack.id) && mine.words.contains { $0.id == word.id }
        }
    }
    var body: some View {
        Form {
            Section("제보 위치") {
                Text(library?.title ?? "내 스택")
                Picker("스택", selection: $selectedStackID) {
                    ForEach(stacks) { Text($0.title).tag(Optional($0.id)) }
                }.onChange(of: selectedStackID) { _, _ in selectedWordID = nil; query = "" }
            }
            if initialWordID == nil {
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
            }
            if let word {
                Section("선택한 카드") { Text(word.japanese); Text(word.korean) }
            }
            Section {
                TextField("올바른 한국어 뜻을 적어 주세요", text: $correctedKorean, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("reportMessage")
                Button(isInMyCards ? "제보 저장 및 내 카드 수정" : "제보 저장") {
                    guard let stack, let word else { return }
                    store.recordMeaningCorrection(library: library, stack: stack, word: word, correctedKorean: correctedKorean)
                    if store.error == nil { dismiss() }
                }.disabled(word == nil || correctedKorean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: { Text("올바른 뜻") } footer: { Text("제보는 기기에 저장됩니다. 내 카드에 있는 단어는 뜻이 즉시 수정되며, 라이브러리 원본은 유지됩니다.") }
        }
        .navigationTitle("틀린 단어 제보")
        .toolbar {
            if initialWordID != nil {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}
