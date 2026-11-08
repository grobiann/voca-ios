import SwiftUI
import VocaCore

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var source = 0
    @State private var sheets = false
    @State private var selectedPublicEntry: PublicDirectoryEntry?
    private var libraries: [Library] { store.archive.libraries }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("덱 위치", selection: $source) { Text("내 덱").tag(0); Text("둘러보기").tag(1) }
                        .pickerStyle(.segmented)
                    if source == 0 {
                        Button { sheets = true } label: {
                            Label("Google Sheets 가져오기", systemImage: "link")
                                .font(.headline).frame(maxWidth: .infinity).padding(16)
                                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        HStack {
                            Text("공개 라이브러리").font(.headline)
                            Spacer()
                            if store.isRefreshingPublicDirectory {
                                ProgressView().accessibilityLabel("공개 라이브러리 새로고침 중")
                            }
                            Button("새로고침") { Task { await store.refreshPublicDirectory() } }
                                .disabled(store.isRefreshingPublicDirectory)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if let publicError = store.publicDirectoryError, source == 1 {
                            Text(publicError).font(.caption).foregroundStyle(.secondary)
                        }
                        if source == 1 { ForEach(store.publicEntries) { entry in
                            Button { selectedPublicEntry = entry } label: {
                                HStack {
                                    Image(systemName: "link").frame(width: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(.subheadline.bold())
                                        if !entry.nickname.isEmpty {
                                            Text("by \(entry.nickname)").font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 17))
                            }.buttonStyle(.plain)
                        } }
                        if libraries.isEmpty && source == 0 { EmptyState(icon: "books.vertical", title: "아직 덱이 없어요", message: "라이브러리 링크를 추가해 주세요.") }
                        if source == 0 { ForEach(libraries) { library in
                        NavigationLink { LibraryDetailView(libraryID: library.id, local: source == 0) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "books.vertical")
                                    .foregroundStyle(Palette.accent).frame(width: 40, height: 40)
                                    .background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(library.title).font(.headline).foregroundStyle(.primary)
                                    Text("\(library.isSentenceDeck ? "문장" : "단어") 덱 · 세트 \(library.stacks.count)개 · 카드 \(library.wordCount)개")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 17))
                        }.buttonStyle(.plain)
                        } }
                    }.padding(.horizontal, 14).padding(.bottom, 14)
                }
            }.background(Palette.canvas).navigationTitle("라이브러리").toolbarTitleDisplayMode(.inline)
                .sheet(isPresented: $sheets) { SheetImportView() }
                .sheet(item: $selectedPublicEntry) { entry in
                    PublicSheetTabsView(entry: entry)
                }
        }
    }


}
struct LibraryDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var libraryID: UUID; var local: Bool
    @State private var deletingLibrary = false
    private var library: Library? { (local ? store.archive.libraries : store.archive.server).first { $0.id == libraryID } }
    var body: some View {
        ScrollView {
            if let library {
                LazyVStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(library.title).font(.title2.bold())
                        Text("\(library.isSentenceDeck ? "문장" : "단어") 덱 · \(library.stacks.count)개 세트 · \(library.wordCount)개 카드").font(.subheadline).foregroundStyle(.secondary)
                        if library.stacks.flatMap(\.words).contains(where: { $0.source == "https://github.com/evanclan/OpenJLPT" }) {
                            Text("한국어 자동번역 · 미검수").font(.caption).foregroundStyle(.secondary)
                            Link("OpenJLPT 및 원본 출처 · CC BY-SA 4.0", destination: URL(string: "https://github.com/evanclan/OpenJLPT/blob/main/NOTICE.md")!).font(.caption)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    ForEach(library.stacks) { stack in
                        let enrolled = store.archive.stacks.first { $0.sourceID == stack.id || $0.id == stack.id }
                        HStack(spacing: 10) {
                            Image(systemName: enrolled?.isComplete == true ? "checkmark.circle.fill" : "rectangle.stack")
                                .foregroundStyle(Palette.accent)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(stack.title).font(.subheadline.bold()).lineLimit(1)
                                Text("\(stack.words.count)개 \(stack.words.first?.isSentence == true ? "문장" : "단어") · \(enrolled?.isComplete == true ? "완료" : enrolled == nil ? "미등록" : "학습 중 \(Int((enrolled?.progress ?? 0) * 100))%")")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if local {
                                NavigationLink { LibraryStackEditor(libraryID: library.id, stackID: stack.id) } label: {
                                    Image(systemName: "pencil").frame(width: 32, height: 40)
                                }.accessibilityLabel("\(stack.title) 카드 관리")
                            }
                            if let enrolled {
                                NavigationLink { StackDetailView(stackID: enrolled.id) } label: {
                                    Image(systemName: "chevron.right").frame(width: 32, height: 40)
                                }.accessibilityLabel("\(stack.title) \(enrolled.isComplete ? "완료한 세트 보기" : "학습 이어가기")")
                            } else {
                                Button { store.enroll(stack) } label: {
                                    Image(systemName: "plus.circle.fill").frame(width: 40, height: 40)
                                }.disabled(stack.words.isEmpty).accessibilityLabel("\(stack.title) 내 스택에 추가")
                            }
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 15))
                    }

                    if local {
                        Button("이 덱 제거", systemImage: "trash", role: .destructive) { deletingLibrary = true }
                            .padding(.top, 32)
                        Text("내 스택에 추가한 학습 사본과 둘러보기의 덱은 유지됩니다.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }.padding(.horizontal, 22).padding(.bottom, 24)
            }
        }.background(Palette.canvas).navigationTitle(library?.title ?? "덱").toolbarTitleDisplayMode(.inline)
            .toolbar {
                if local {
                    Menu {
                        Button("덱 제거", systemImage: "trash", role: .destructive) { deletingLibrary = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("덱 관리")
                }
            }

            .confirmationDialog("덱을 제거할까요?", isPresented: $deletingLibrary, titleVisibility: .visible) {
                Button("이 기기에서 덱 제거", role: .destructive) { store.removeLibrary(libraryID); dismiss() }
            } message: { Text("내 스택에 추가한 카드는 유지됩니다. 둘러보기의 기존 사본도 유지됩니다.") }
    }
}

struct LibraryStackEditor: View {
    @Environment(AppStore.self) private var store
    let libraryID: UUID; let stackID: UUID
    private var stack: Stack? { store.archive.libraries.first { $0.id == libraryID }?.stacks.first { $0.id == stackID } }
    var body: some View {
        List {
            ForEach(stack?.words ?? []) { word in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(word.japanese).font(.headline).textSelection(.enabled)
                        Spacer()
                        CopyJapaneseButton(text: word.japanese)
                        SearchButtons(text: word.japanese)
                    }
                    Text(word.korean)
                }
            }.onDelete { offsets in mutate { $0.words.remove(atOffsets: offsets) } }

        }.navigationTitle(stack?.title ?? "스택")
    }
    private func mutate(_ edit: (inout Stack) -> Void) {
        guard let i = store.archive.libraries.firstIndex(where: { $0.id == libraryID }), let j = store.archive.libraries[i].stacks.firstIndex(where: { $0.id == stackID }) else { return }
        edit(&store.archive.libraries[i].stacks[j]); store.save()
    }
}
struct SheetImportView: View {
    var initialLink: String = ""
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
                    if !tabs.isEmpty {
                        Picker("가져올 덱", selection: $selectedID) {
                            ForEach(tabs) { Text($0.name).tag($0.id) }
                        }.onChange(of: selectedID) { _, value in name = tabs.first { $0.id == value }?.name ?? "" }
                        TextField("덱 이름", text: $name)
                    }
                }
                Section {
                    Text("시트를 ‘링크가 있는 모든 사용자: 뷰어’로 공유하고 원본 링크를 입력해 주세요. 파일의 실제 시트 목록에서 하나를 선택합니다.")
                    Text("필수 열: stack, ja-JP, ko-KR. 읽는 법은 ja-JP-reading, 고정 ID는 card_id(선택) 열을 사용하세요. 문장은 type에 sentence를 적으세요.").font(.caption)
                    Text("JLPT 단어장은 비공식 공개 목록이며 한국어 자동번역은 미검수입니다. 가져온 데이터는 로컬 사본으로 저장되며 자동 동기화되지 않습니다.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Button { load() } label: { if loading { ProgressView() } else { Text(tabs.isEmpty ? "시트 목록 확인" : "가져오기") } }.disabled(loading || link.isEmpty || (!tabs.isEmpty && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }.navigationTitle("시트에서 가져오기").toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { task?.cancel(); dismiss() } } }
        }.onAppear { if link.isEmpty { link = initialLink } }.onDisappear { task?.cancel() }
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
                guard let raw = String(data: data, encoding: .utf8),
                      let header = try LibraryImporter.parseCSV(raw.replacingOccurrences(of: "\u{FEFF}", with: "")).first else {
                    throw ImportFailure.invalid("시트 첫 행을 읽을 수 없습니다.")
                }
                let names = Set(header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
                guard names.contains("stack") else {
                    throw ImportFailure.invalid("덱에 stack 및 두 개의 언어 코드 열이 필요합니다.")
                }
                var library = try LibraryImporter.read(data, filename: selectedSheet + ".csv", namespace: url.absoluteString)
                library.title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                store.archive.installImportedLibrary(library)
                store.registerSheetLink(link)
                store.save(); dismiss()
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}

struct PublicSheetTabsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: PublicDirectoryEntry
    @State private var tabs: [SheetURL.Tab] = []
    @State private var loading = false
    @State private var importingID: String?
    @State private var error: String?
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !entry.description.isEmpty || !entry.nickname.isEmpty {
                    Section {
                        if !entry.description.isEmpty { Text(entry.description).font(.subheadline) }
                        if !entry.nickname.isEmpty { Text("등록자 · \(entry.nickname)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if loading { ProgressView("시트 목록을 읽는 중…") }
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(tabs) { tab in
                    let enrolled = isImported(tab)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tab.name).font(.headline)
                            Text(enrolled ? "내 덱에 등록됨" : "등록 가능")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(importingID == tab.id ? "가져오는 중…" : enrolled ? "갱신" : "등록") {
                            Task { await importTab(tab) }
                        }.disabled(importingID != nil)
                    }.padding(.vertical, 4)
                }
            }
            .navigationTitle(entry.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .navigationDestination(for: UUID.self) { id in LibraryDetailView(libraryID: id, local: true) }
            .task { await loadTabs() }
        }
    }
    private func isImported(_ tab: SheetURL.Tab) -> Bool {
        guard let url = try? SheetURL.csvURL(from: entry.link, tab: tab) else { return false }
        return store.archive.libraries.contains { $0.id == LibraryImporter.stableID(url.absoluteString) }
    }
    private func loadTabs() async {
        loading = true; defer { loading = false }
        do {
            var request = URLRequest(url: try SheetURL.manifestURL(from: entry.link)); request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 5_000_000 else {
                throw ImportFailure.invalid("시트 목록을 읽을 수 없습니다.")
            }
            tabs = try SheetURL.tabs(from: data)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func importTab(_ tab: SheetURL.Tab) async {
        importingID = tab.id; defer { importingID = nil }
        do {
            let url = try SheetURL.csvURL(from: entry.link, tab: tab)
            var request = URLRequest(url: url); request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  data.count <= 10_000_000, let raw = String(data: data, encoding: .utf8),
                  let header = try LibraryImporter.parseCSV(raw.replacingOccurrences(of: "\u{FEFF}", with: "")).first else {
                throw ImportFailure.invalid("시트 데이터를 읽을 수 없습니다.")
            }
            let names = Set(header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            guard names.contains("stack") else {
                throw ImportFailure.invalid("stack 및 두 개의 언어 코드 열이 필요합니다.")
            }
            var library = try LibraryImporter.read(data, filename: tab.name + ".csv", namespace: url.absoluteString)
            library.title = tab.name
            store.archive.installImportedLibrary(library)
            store.registerSheetLink(entry.link)
            store.save()
            error = nil
            path.append(library.id)
        } catch { self.error = error.localizedDescription }
    }
}
