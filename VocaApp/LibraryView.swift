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
    var libraryID: UUID; var local: Bool
    @State private var add = false
    @State private var uploaded = false
    private var library: Library? { (local ? store.archive.libraries : store.archive.server).first { $0.id == libraryID } }
    var body: some View {
        List {
            if let library {
                Section {
                    Text(library.subtitle).foregroundStyle(.secondary)
                    Text("\(library.stacks.count)개 스택 · \(library.wordCount)개 단어")
                    if local {
                        Button { store.publish(library); uploaded = true } label: { Label("서버에 올리기", systemImage: "arrow.up.circle") }.disabled(library.wordCount == 0)
                        Text("현재는 기기 안의 가짜 서버에 저장되며 둘러보기에 표시됩니다.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("스택") {
                    ForEach(library.stacks) { stack in
                        VStack(alignment: .leading, spacing: 12) {
                            if local {
                                NavigationLink { LibraryStackEditor(libraryID: library.id, stackID: stack.id) } label: {
                                    VStack(alignment: .leading) { Text(stack.title).font(.headline); Text("\(stack.words.count)개 단어 · 카드 관리").font(.caption).foregroundStyle(.secondary) }
                                }
                            } else {
                                Text(stack.title).font(.headline)
                                Text(stack.words.prefix(3).map(\.japanese).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            }
                            Button { store.enroll(stack) } label: { Label(store.isEnrolled(stack) ? "내 스택에 등록됨" : "내 스택에 추가", systemImage: store.isEnrolled(stack) ? "checkmark" : "plus") }
                                .disabled(store.isEnrolled(stack) || stack.words.isEmpty)
                        }.padding(.vertical, 6)
                    }
                    if local { Button("스택 만들기", systemImage: "plus") { add = true } }
                }
            }
        }.navigationTitle(library?.title ?? "라이브러리")
            .sheet(isPresented: $add) { NameSheet(title: "새 스택", placeholder: "스택 이름") { name in
                guard let i = store.archive.libraries.firstIndex(where: { $0.id == libraryID }) else { return }
                store.archive.libraries[i].stacks.append(Stack(title: name)); store.save()
            } }
            .alert("둘러보기에 등록했어요", isPresented: $uploaded) { Button("확인", role: .cancel) {} } message: { Text("이 기기에서 가짜 서버의 목록을 확인할 수 있어요.") }
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
                VStack(alignment: .leading, spacing: 6) { Text(word.japanese).font(.headline); Text(word.korean); Text(word.example).font(.caption).foregroundStyle(.secondary) }
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
    @State private var name = "Google Sheets 단어장"
    @State private var loading = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Form {
                Section("Google Sheets") {
                    TextField("라이브러리 이름", text: $name)
                    TextField("https://docs.google.com/spreadsheets/…", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Text("시트를 ‘링크가 있는 모든 사용자: 뷰어’로 공유하거나 웹에 게시해 주세요. 선택한 탭의 데이터를 가져옵니다.")
                    Text("첫 행: japanese, korean, example\n선택 열: stack (스택 이름)").font(.system(.caption, design: .monospaced))
                    Text("가져온 데이터는 로컬 사본으로 저장되며 자동 동기화되지 않습니다.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Button { load() } label: { if loading { ProgressView() } else { Text("가져오기") } }.disabled(loading || link.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.navigationTitle("시트에서 가져오기").toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { task?.cancel(); dismiss() } } }
        }.onDisappear { task?.cancel() }
    }
    private func load() {
        loading = true; error = nil
        task = Task { @MainActor in
            defer { loading = false }
            do {
                let url = try SheetURL.csvURL(from: link)
                var request = URLRequest(url: url); request.timeoutInterval = 30
                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      !(http.mimeType ?? "").contains("html") else { throw ImportFailure.invalid("시트를 읽을 수 없습니다. 공유 설정과 링크를 확인해 주세요.") }
                guard data.count <= 10_000_000 else { throw ImportFailure.invalid("10MB 이하의 시트를 가져와 주세요.") }
                var library = try LibraryImporter.read(data, filename: "sheet.csv")
                library.title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                store.archive.libraries.append(library); store.save(); dismiss()
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}
