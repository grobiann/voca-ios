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
                Section {
                    NavigationLink("학습 설정") { StudySettingsView() }
                    NavigationLink("Google Sheets 목록") { SheetLinksView() }
                    NavigationLink("검색 버튼 설정") { SearchSettingsView() }
                    NavigationLink("내 카드 뜻 수정 기록") { WordReportList() }
                    NavigationLink("개인정보 처리방침") { PrivacyPolicyView() }
                    LabeledContent("버전", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    NavigationLink("개발자") { DeveloperStoryView() }
                }
            }.navigationTitle("설정")
        }
    }
}

struct SearchSettingsView: View {
    @Environment(AppStore.self) private var store
    private func binding<Value>(for provider: SearchProvider, keyPath: WritableKeyPath<SearchProvider, Value>) -> Binding<Value> {
        Binding(
            get: { store.searchProviders.first(where: { $0.id == provider.id })?[keyPath: keyPath] ?? provider[keyPath: keyPath] },
            set: { value in
                guard let index = store.searchProviders.firstIndex(where: { $0.id == provider.id }) else { return }
                store.searchProviders[index][keyPath: keyPath] = value
            }
        )
    }
    var body: some View {
        List {
            Section {
                ForEach(store.searchProviders) { provider in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Toggle("검색 버튼 표시", isOn: binding(for: provider, keyPath: \.enabled))
                            Spacer()
                            if !["Google", "한자 공부방"].contains(provider.name) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.searchProviders.removeAll { $0.id == provider.id }
                                    }
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(provider.name.isEmpty ? "이 검색 사이트" : provider.name) 삭제")
                            }
                        }
                        TextField("버튼 이름", text: binding(for: provider, keyPath: \.name))
                        TextField("https://example.com/search?q={query}", text: binding(for: provider, keyPath: \.template), axis: .vertical)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            .font(.footnote)
                        Button("時間으로 검색 확인") {
                            if let current = store.searchProviders.first(where: { $0.id == provider.id }) {
                                store.search("時間", using: current)
                            }
                        }
                            .buttonStyle(.borderless).font(.caption)
                    }.padding(.vertical, 6)
                }
                .onDelete { store.searchProviders.remove(atOffsets: $0) }
                .onMove { store.searchProviders.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("검색어 위치에 {query}를 넣어 주세요. 켜진 항목만 목록 순서대로 카드에 표시됩니다. 추가한 사이트는 휴지통 버튼으로 삭제하고, 편집에서 순서를 바꿀 수 있습니다.")
            }
            Button("검색 사이트 추가", systemImage: "plus") {
                store.searchProviders.append(SearchProvider(name: "", template: "", enabled: false))
            }
        }.navigationTitle("검색 버튼 설정")
            .toolbar { EditButton() }
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
                        ShareLink(item: report.shareText) { Label("수정 내용 공유", systemImage: "square.and.arrow.up") }
                    }.padding(.vertical, 6)
                }
                if (store.archive.wordReports ?? []).isEmpty { Text("수정 기록이 없어요.").foregroundStyle(.secondary) }
            } footer: { Text("수정 기록은 이 기기에만 저장됩니다. 원본 Google Sheet나 작성자에게 자동으로 전달되지 않습니다.") }
        }.navigationTitle("내 카드 뜻 수정 기록")
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
        let inStack = store.archive.stacks.contains { mine in
            (mine.id == stack.id || mine.sourceID == stack.id) && mine.words.contains { $0.id == word.id }
        }
        let inLibrary = store.archive.libraries.contains { mine in
            mine.id == library?.id && mine.stacks.contains { deck in
                (deck.id == stack.id || deck.id == stack.sourceID) && deck.words.contains { $0.id == word.id }
            }
        }
        return inStack || inLibrary
    }
    var body: some View {
        Form {
            Section("수정할 카드") {
                Text(library?.title ?? "내 스택")
                Picker("스택", selection: $selectedStackID) {
                    ForEach(stacks) { Text($0.title).tag(Optional($0.id)) }
                }.onChange(of: selectedStackID) { _, _ in selectedWordID = nil; query = "" }
            }
            if initialWordID == nil {
                Section("카드 선택") {
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
                Button("내 카드 뜻 수정") {
                    guard let stack, let word else { return }
                    store.recordMeaningCorrection(library: library, stack: stack, word: word, correctedKorean: correctedKorean)
                    if store.error == nil { dismiss() }
                }.disabled(!isInMyCards || correctedKorean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: { Text("수정할 뜻") } footer: {
                Text(isInMyCards
                     ? "내 카드의 뜻과 수정 기록은 이 기기에 저장됩니다. 원본 Google Sheet는 바뀌지 않습니다."
                     : "수정하려면 먼저 이 덱을 내 덱에 추가하거나 스택을 내 스택에 등록해 주세요.")
            }
        }
        .navigationTitle("내 카드 뜻 수정")
        .toolbar {
            if initialWordID != nil {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("기기에 저장하는 정보") {
                Text("단어, 라이브러리, 학습 진행, 반복 학습 목록, 뜻 수정 기록과 검색 설정은 이 기기에 저장됩니다. 로그인, 광고, 추적 및 학습 데이터의 자동 전송 기능은 없습니다.")
            }
            Section("외부 서비스") {
                Text("Google Sheets 가져오기를 실행하면 Google에 접속해 공개된 시트를 읽습니다. 공개 공유한 시트는 링크를 아는 다른 사람도 볼 수 있으므로 개인정보를 넣지 마세요.")
                Text("검색 버튼을 누르면 일본어 단어가 선택한 검색 사이트로 전달되고 외부 브라우저가 열립니다. 해당 서비스의 개인정보 처리방침이 적용됩니다.")
                Text("뜻 수정 기록은 자동으로 전송되지 않습니다. 공유를 선택하면 선택한 앱과 수신자에게 수정 내용이 전달됩니다.")
                Text("개발자 화면에서 좋아요 버튼을 누르면 앱이 임의로 만든 앱 전용 ID와 좋아요 1회가 Google Apps Script로 전송됩니다. 운영자의 비공개 Google Sheet에 ID별 횟수와 날짜별 합계가 저장됩니다. 계정, 이메일, 실제 기기 ID와 학습 데이터는 보내지 않습니다.")
            }
            Section("보관과 삭제") {
                Text("앱 안에서 스택과 라이브러리를 삭제할 수 있습니다. 기기에 저장된 전체 데이터를 지우려면 iPhone 설정에서 앱을 삭제하세요. 앱 정리하기는 데이터 삭제와 다릅니다.")
                Text("앱 자체의 기기 간 동기화는 없습니다. iCloud 또는 기기 백업에 포함되는 데이터는 사용자의 Apple 백업 설정에 따릅니다. 외부로 공유한 사본은 해당 서비스에서 별도로 삭제해야 합니다.")
            }
            Section("권한") {
                Text("알림, 알람, 카메라, 마이크, 사진 및 연락처 권한을 요청하지 않습니다.")
            }
            Section("운영자 및 문의") {
                Text("CardVoca · 장진석")
                Link("grobiann0@gmail.com", destination: URL(string: "mailto:grobiann0@gmail.com")!)
                Text("이메일 문의의 주소와 내용은 답변 목적으로 처리하고, 처리 후 불필요한 정보는 삭제합니다. 법령상 보관 의무가 있으면 해당 기간 동안 보관합니다. 개인정보 열람·정정·삭제도 이메일로 요청할 수 있습니다.")
                Text("시행일: 2026년 11월 4일")
            }
        }.navigationTitle("개인정보 처리방침")
    }
}

struct DeveloperStoryView: View {
    @State private var likesTapped = 0
    var body: some View {
        List {
            Section {
                Text("제가 일본어를 공부하려고 만든 앱이고, 지금도 직접 사용하고 있습니다. 제 공부에 필요한 방향으로 계속 발전시켜 나갈 생각이에요.")
                Text("수익화를 목적으로 만든 앱은 아니고, 앞으로도 수익화할 계획은 없습니다. 편하게 사용해 주세요.")
                Text("인터넷에 공유된 단어 목록을 샘플로 넣어 두었습니다. 각자 필요한 자료를 기기에 추가하거나 다른 사람과 공유할 수도 있어요. 앞으로는 문장이나 조금 더 어려운 내용도 더해질 수 있습니다. 다른 언어도 언젠가는요… 제 일본어 공부가 먼저 끝나면요! 😄")
                Text("현재 들어 있는 단어와 앞으로 추가할 내용 중에는 AI로 만든 자료도 있습니다. 틀린 내용이 있을 수 있으니 참고하며 공부해 주세요.")
            }
            Section {
                Button {
                    likesTapped += 1
                    Task { await LikeFeedback.send() }
                } label: {
                    Label("눌러서 개발자에게 좋아요 전달하기", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                        .symbolEffect(.bounce, value: likesTapped)
                }
            }
        }.navigationTitle("개발자")
    }
}

struct StudySettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showingWaitOptions = false
    private let waitOptions: [(Int, String)] = [(0,"재학습시"),(10,"10분"),(30,"30분"),(60,"1시간"),(120,"2시간"),(180,"3시간"),(240,"4시간"),(360,"6시간"),(720,"12시간"),(1440,"1일"),(2880,"2일"),(4320,"3일"),(10080,"1주일")]
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("히라가나·가타카나 모드", isOn: $store.kanaStudyMode)
                Toggle("앞면에 히라가나 표시", isOn: $store.showReadingOnFront)
                    .disabled(store.kanaStudyMode)
                Toggle("단방향 학습 (일본어 → 한국어)", isOn: $store.oneWayStudy)
                    Stepper("학습 풀 크기: \(store.poolSize)개", value: $store.poolSize, in: 1...100)
                    Stepper("반복 학습 풀 크기: \(store.reviewPoolSize)개", value: $store.reviewPoolSize, in: 1...100)
                    Toggle("일일 학습 목표 설정", isOn: $store.dailyStudyLimitEnabled)
                    Stepper("일일 학습 목표: \(store.dailyStudyLimit)회", value: $store.dailyStudyLimit, in: 10...1000, step: 10)
                        .disabled(!store.dailyStudyLimitEnabled)
                    Stepper("반복 학습 단계: \(store.reviewDepthCount)단계", value: $store.reviewDepthCount, in: store.highestUsedReviewDepth...20)
                    Button { showingWaitOptions = true } label: {
                        HStack {
                            Text("반복학습 단계업 대기시간")
                            Spacer()
                            Text(waitOptions.first(where: { $0.0 == store.reviewWaitMinutes })?.1 ?? "1일")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }.buttonStyle(.plain)
                    HStack(spacing: 6) {
                        Text("카드 햅틱 피드백")
                        InfoButton("카드를 넘기거나 답을 선택할 때 아이폰이 짧게 진동해 동작을 알려주는 기능입니다.")
                        Spacer(minLength: 0)
                        Toggle("카드 햅틱 피드백", isOn: $store.haptics)
                            .labelsHidden()
                            .onChange(of: store.haptics) { _, value in UserDefaults.standard.set(value, forKey: "haptics") }
                    }
            }
        }.navigationTitle("학습 설정")
            .sheet(isPresented: $showingWaitOptions) {
                NavigationStack {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(waitOptions, id: \.0) { option in
                            Button {
                                store.reviewWaitMinutes = option.0
                                showingWaitOptions = false
                            } label: {
                                HStack {
                                    Text(option.1)
                                    Spacer(minLength: 4)
                                    if store.reviewWaitMinutes == option.0 { Image(systemName: "checkmark") }
                                }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(store.reviewWaitMinutes == option.0 ? Palette.accent.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Palette.canvas)
                    .navigationTitle("단계업 대기시간")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { showingWaitOptions = false } } }
                }
                .presentationDetents([.height(530), .large])
            }
    }
}

private struct InfoButton: View {
    let message: String
    @State private var showing = false
    init(_ message: String) { self.message = message }
    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "questionmark.circle")
                .font(.subheadline)
                .frame(width: 24, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("카드 햅틱 피드백 설명")
        .alert("카드 햅틱 피드백", isPresented: $showing) {
            Button("확인", role: .cancel) { }
        } message: { Text(message) }
    }
}

struct SheetLinksView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    var body: some View {
        List {

            Section("내가 등록한 Google Sheets") {
                ForEach(store.sheetLinks, id: \.self) { link in
                    HStack {
                        Text(link).font(.caption).textSelection(.enabled)
                        Spacer()
                        if let requestURL = publicationRequestURL(for: link) {
                            Link(destination: requestURL) {
                                Label("공개 등록 요청", systemImage: "square.and.arrow.up")
                                    .labelStyle(.iconOnly).frame(width: 44, height: 44)
                            }.accessibilityLabel("이 시트 공개 등록 요청")
                        }
                    }.swipeActions { Button("제거", role: .destructive) { store.removeSheetLink(link) } }
                }
                Button("Google Sheets 추가", systemImage: "plus") { adding = true }
            }
            Section {
                Text("등록 요청은 Google 계정당 한 번 제출할 수 있습니다. 운영자가 내용을 확인한 뒤 공개 목록에 추가합니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Google Sheets 목록")
            .sheet(isPresented: $adding) { SheetImportView() }
    }
    private func publicationRequestURL(for link: String) -> URL? {
        guard var components = URLComponents(string: "https://docs.google.com/forms/d/e/1FAIpQLScBdgPR8fvde4wA2Lnmz8KMz48-KzmLAW0TR6n8Fva9Co20Cg/viewform") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "usp", value: "pp_url"),
            URLQueryItem(name: "entry.805694570", value: link)
        ]
        return components.url
    }

}
