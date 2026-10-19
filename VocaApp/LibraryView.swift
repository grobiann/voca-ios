import SwiftUI
import UniformTypeIdentifiers
import VocaCore

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var source = 0
    @State private var creating = false
    @State private var importing = false
    @State private var sheets = false
    @State private var query = ""
    private var libraries: [Library] { (source == 0 ? store.archive.libraries : store.archive.server).filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("말의 세계를 넓혀요.").font(.largeTitle.bold())
                        Text("좋아하는 주제를 담고, 내 속도로 배워요.").foregroundStyle(.secondary)
                    }
                    Picker("라이브러리 위치", selection: $source) { Text("내 라이브러리").tag(0); Text("둘러보기").tag(1) }.pickerStyle(.segmented)
                    if source == 0 {
                        Menu {
                            Button("직접 만들기", systemImage: "plus") { creating = true }
                            Button("JSON / CSV 파일", systemImage: "doc") { importing = true }
                            Button("Google Sheets 링크", systemImage: "link") { sheets = true }
                        } label: {
                            Label("만들기 또는 가져오기", systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity).padding(22)
                                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                        }
                    } else {
                        Label("미리 준비한 모음과 업로드한 라이브러리", systemImage: "books.vertical").font(.caption).foregroundStyle(.secondary)
                    }
                    if libraries.isEmpty { EmptyState(icon: "books.vertical", title: "아직 라이브러리가 없어요", message: "단어를 직접 모으거나 파일과 Google Sheets에서 가져오세요.") }
                    ForEach(libraries) { library in
                        NavigationLink { LibraryDetailView(libraryID: library.id, local: source == 0) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("COLLECTION").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(3)
                                        Text(library.title).font(.title2.bold()).multilineTextAlignment(.leading)
                                    }
                                    Spacer(); Image(systemName: "text.book.closed").font(.system(size: 42, weight: .ultraLight))
                                }.foregroundStyle(.white).padding(26).frame(maxWidth: .infinity, minHeight: 150)
                                    .background(LinearGradient(colors: [Palette.accent, Palette.accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(library.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                    Text("스택 \(library.stacks.count)개   ·   단어 \(library.wordCount)개").font(.caption.bold())
                                }.padding(22)
                            }.background(.background).clipShape(RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain)
                    }
                }.padding(22)
            }.background(Palette.canvas).navigationTitle("라이브러리").toolbarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "라이브러리 검색")
                .sheet(isPresented: $creating) { NameSheet(title: "새 라이브러리", placeholder: "라이브러리 이름") { name in store.archive.libraries.append(Library(title: name)); store.save() } }
                .sheet(isPresented: $sheets) { SheetImportView() }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .commaSeparatedText], allowsMultipleSelection: false) { result in
                    do {
                        guard let url = try result.get().first else { return }
                        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let library = try LibraryImporter.read(Data(contentsOf: url), filename: url.lastPathComponent)
                        store.archive.libraries.append(library); store.save()
                    } catch { store.error = error.localizedDescription }
                }
        }
    }
}
struct LibraryDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var libraryID: UUID; var local: Bool
    @State private var add = false
    @State private var uploaded = false
    @State private var deletingLibrary = false
    private var library: Library? { (local ? store.archive.libraries : store.archive.server).first { $0.id == libraryID } }
    var body: some View {
        ScrollView {
            if let library {
                LazyVStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text(library.title).font(.largeTitle.bold())
                        Text("\(library.stacks.count)개 스택 · \(library.wordCount)개 단어").foregroundStyle(.secondary)
                        if library.stacks.flatMap(\.words).contains(where: { $0.source == "https://github.com/evanclan/OpenJLPT" }) {
                            Text("한국어 자동번역 · 예문 일부 AI 작성 · 미검수").font(.caption).foregroundStyle(.secondary)
                            Link("OpenJLPT 및 원본 출처 · CC BY-SA 4.0", destination: URL(string: "https://github.com/evanclan/OpenJLPT/blob/main/NOTICE.md")!).font(.caption)
                        }
                        if local {
                            Button { store.publish(library); uploaded = true } label: { Label("서버에 올리기", systemImage: "arrow.up.circle") }.disabled(library.wordCount == 0)
                            Text("이 기기의 둘러보기에 저장됩니다.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(28)
                    ForEach(Array(library.stacks.enumerated()), id: \.element.id) { index, stack in
                        if index > 0 {
                            Image(systemName: "chevron.down.2").font(.title2.bold()).foregroundStyle(Palette.accent.opacity(0.25)).frame(height: 65)
                        }
                        let enrolled = store.archive.stacks.first { $0.sourceID == stack.id || $0.id == stack.id }
                        VStack(spacing: 18) {
                            ZStack {
                                Circle().stroke(Palette.accent.opacity(0.12), lineWidth: 7)
                                Circle().trim(from: 0, to: enrolled?.progress ?? 0)
                                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                                Image(systemName: enrolled?.isComplete == true ? "checkmark.seal.fill" : "text.book.closed")
                                    .font(.system(size: 40, weight: .light)).foregroundStyle(Palette.accent)
                            }.frame(width: 106, height: 106).accessibilityHidden(true)
                            Text(stack.title).font(.title3.bold())
                            Text("\(stack.words.count)개 단어 · \(enrolled?.isComplete == true ? "완료" : enrolled == nil ? "아직 시작하지 않았어요" : "학습 중 \(Int((enrolled?.progress ?? 0) * 100))%")")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(stack.words.prefix(3).map(\.japanese).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            NavigationLink("틀린 단어 제보") { WordReportComposer(library: library, stacks: [stack]) }.font(.caption)
                            if let enrolled {
                                NavigationLink { StackDetailView(stackID: enrolled.id) } label: {
                                    Label(enrolled.isComplete ? "완료한 스택 보기" : "학습 이어가기", systemImage: enrolled.isComplete ? "checkmark" : "play.fill")
                                }.buttonStyle(PrimaryButton())
                            } else {
                                Button { store.enroll(stack) } label: { Label("내 스택에 추가", systemImage: "plus") }
                                    .buttonStyle(PrimaryButton()).disabled(stack.words.isEmpty)
                            }
                            if local {
                                NavigationLink("카드 관리") { LibraryStackEditor(libraryID: library.id, stackID: stack.id) }.font(.caption)
                            }
                        }.padding(26).frame(maxWidth: .infinity).background(.background, in: RoundedRectangle(cornerRadius: 26))
                    }
                    if local { Button("스택 만들기", systemImage: "plus") { add = true }.padding(26) }
                    if local {
                        Button("이 라이브러리 제거", systemImage: "trash", role: .destructive) { deletingLibrary = true }
                            .padding(.top, 32)
                        Text("내 스택에 추가한 학습 사본과 둘러보기의 라이브러리는 유지됩니다.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }.padding(.horizontal, 22).padding(.bottom, 24)
            }
        }.background(Palette.canvas).navigationTitle("스택 목록").toolbarTitleDisplayMode(.inline)
            .toolbar {
                if let library {
                    NavigationLink { WordReportComposer(library: library, stacks: library.stacks) } label: { Label("라이브러리 오류 제보", systemImage: "flag") }
                }
                if local {
                    Menu {
                        Button("라이브러리 제거", systemImage: "trash", role: .destructive) { deletingLibrary = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("라이브러리 관리")
                }
            }
            .sheet(isPresented: $add) { NameSheet(title: "새 스택", placeholder: "스택 이름") { name in
                guard let i = store.archive.libraries.firstIndex(where: { $0.id == libraryID }) else { return }
                store.archive.libraries[i].stacks.append(Stack(title: name)); store.save()
            } }
            .alert("둘러보기에 등록했어요", isPresented: $uploaded) { Button("확인", role: .cancel) {} }
            .confirmationDialog("라이브러리를 제거할까요?", isPresented: $deletingLibrary, titleVisibility: .visible) {
                Button("이 기기에서 라이브러리 제거", role: .destructive) { store.removeLibrary(libraryID); dismiss() }
            } message: { Text("내 스택에 추가한 카드는 유지됩니다. 둘러보기에 올린 사본도 유지됩니다.") }
    }
}

struct LibraryStackEditor: View {
    @Environment(AppStore.self) private var store
    let libraryID: UUID; let stackID: UUID
    @State private var add = false
    private var stack: Stack? { store.archive.libraries.first { $0.id == libraryID }?.stacks.first { $0.id == stackID } }
    var body: some View {
        List {
            ForEach(stack?.words ?? []) { word in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(word.japanese).font(.headline).textSelection(.enabled); Spacer(); CopyJapaneseButton(text: word.japanese) }
                    Text(word.korean); Text(word.example).font(.caption).foregroundStyle(.secondary)
                }
            }.onDelete { offsets in mutate { $0.words.remove(atOffsets: offsets) } }
            Button("카드 추가", systemImage: "plus") { add = true }
        }.navigationTitle(stack?.title ?? "스택").sheet(isPresented: $add) { CardEditor { word in mutate { $0.words.append(word) } } }
    }
    private func mutate(_ edit: (inout Stack) -> Void) {
        guard let i = store.archive.libraries.firstIndex(where: { $0.id == libraryID }), let j = store.archive.libraries[i].stacks.firstIndex(where: { $0.id == stackID }) else { return }
        edit(&store.archive.libraries[i].stacks[j]); store.save()
    }
}
struct SheetImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var name = "N5"
    @State private var selectedID = ""
    @State private var tabs: [SheetURL.Tab] = []
    @State private var loading = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Form {
                Section("Google Sheets") {
                    TextField("https://docs.google.com/spreadsheets/…", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("sheetLink")
                        .onChange(of: link) { _, _ in task?.cancel(); tabs = []; selectedID = "" }
                    Button("JLPT N5–N1 단어장 링크 사용") {
                        link = "https://docs.google.com/spreadsheets/d/1CZiD8VuxZ6iqrMeBGREO-MAhStjL-dOIJQsj2SiP-Q4/edit"
                    }
                    if !tabs.isEmpty {
                        Picker("가져올 시트", selection: $selectedID) {
                            ForEach(tabs) { Text($0.name).tag($0.id) }
                        }.onChange(of: selectedID) { _, value in name = tabs.first { $0.id == value }?.name ?? "" }
                        TextField("라이브러리 이름", text: $name)
                    }
                }
                Section {
                    Text("시트를 ‘링크가 있는 모든 사용자: 뷰어’로 공유하고 원본 링크를 입력해 주세요. 파일의 실제 시트 목록에서 하나를 선택합니다.")
                    Text("필수 열: japanese, korean, example\n스택 구분: stack_id, stack\n카드 식별: card_id · 읽기: reading").font(.system(.caption, design: .monospaced))
                    Text("JLPT 단어장은 비공식 공개 목록이며 한국어 자동번역과 일부 작성 예문은 미검수입니다. 가져온 데이터는 로컬 사본으로 저장되며 자동 동기화되지 않습니다.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Button { load() } label: { if loading { ProgressView() } else { Text(tabs.isEmpty ? "시트 목록 확인" : "가져오기") } }.disabled(loading || link.isEmpty || (!tabs.isEmpty && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }.navigationTitle("시트에서 가져오기").toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { task?.cancel(); dismiss() } } }
        }.onDisappear { task?.cancel() }
    }
    private func load() {
        loading = true; error = nil
        task = Task { @MainActor in
            defer { loading = false }
            do {
                if tabs.isEmpty {
                    var request = URLRequest(url: try SheetURL.manifestURL(from: link)); request.timeoutInterval = 30
                    let (data, response) = try await URLSession.shared.data(for: request)
                    try Task.checkCancellation()
                    guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 5_000_000 else {
                        throw ImportFailure.invalid("시트 목록을 읽을 수 없습니다. 링크와 공유 설정을 확인해 주세요.")
                    }
                    tabs = try SheetURL.tabs(from: data)
                    selectedID = tabs.first?.id ?? ""
                    name = tabs.first?.name ?? ""
                    return
                }
                guard let selected = tabs.first(where: { $0.id == selectedID }) else { return }
                let selectedSheet = selected.name
                let url = try SheetURL.csvURL(from: link, tab: selected)
                var request = URLRequest(url: url); request.timeoutInterval = 30
                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      !(http.mimeType ?? "").contains("html") else { throw ImportFailure.invalid("시트를 읽을 수 없습니다. 공유 설정과 링크를 확인해 주세요.") }
                guard data.count <= 10_000_000 else { throw ImportFailure.invalid("10MB 이하의 시트를 가져와 주세요.") }
                var library = try LibraryImporter.read(data, filename: selectedSheet + ".csv", namespace: url.absoluteString)
                library.title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if let i = store.archive.libraries.firstIndex(where: { $0.id == library.id }) {
                    store.archive.libraries[i] = library
                } else { store.archive.libraries.append(library) }
                store.save(); dismiss()
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}
