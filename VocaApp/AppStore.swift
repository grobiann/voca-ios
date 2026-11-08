import SwiftUI
import VocaCore

struct ReviewDepthAdvanceSnapshot {
    let sourceDepth: Int
    let previousDestination: Stack?
    let destinationDepth: Int?
    let previousCompleted: [Word]
}

struct SearchProvider: Identifiable, Codable {
    var id = UUID()
    var name: String
    var template: String
    var enabled = true

    static func load() -> [SearchProvider] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            return [SearchProvider(name: "Google", template: "https://www.google.com/search?q={query} 한자 해석"),
                    SearchProvider(name: "한자 공부방", template: "https://nihongokanji.com/?s={query}")]
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: "searchProviders"),
           var saved = try? JSONDecoder().decode([SearchProvider].self, from: data) {
            if let index = saved.firstIndex(where: { $0.name == "Google" }) {
                saved[index].template = saved[index].template
                    .replacingOccurrences(of: "%20한자%20해석", with: " 한자 해석")
            }
            return saved
        }
        return [
            SearchProvider(name: "Google", template: "https://www.google.com/search?q={query} 한자 해석"),
            SearchProvider(name: "한자 공부방", template: UserDefaults.standard.string(forKey: "kanjiSearchTemplate") ?? "https://nihongokanji.com/?s={query}")
        ]
    }
}

struct PublicDirectoryEntry: Identifiable {
    let name: String
    let link: String
    let description: String
    let nickname: String
    var id: String { link }
}

@MainActor @Observable final class AppStore {
    var archive: Archive
    var error: String?
    var searchProviders = SearchProvider.load() {
        didSet {
            if let data = try? JSONEncoder().encode(searchProviders) {
                UserDefaults.standard.set(data, forKey: "searchProviders")
            }
        }
    }
    // Only the directory address is bundled; library URLs come from its public rows.
    private let directoryURL = "https://docs.google.com/spreadsheets/d/1ffae20f-FFBJCvyIiu49kj1UKz3YuMMQYFYKiJmEbVw/edit?gid=349747093"
    var publicEntries: [PublicDirectoryEntry] = []
    var publicDirectoryError: String?
    var sheetLinks: [String] { archive.sheetLinks ?? [] }
    func refreshPublicDirectory() async {
        do {
            let url = try SheetURL.csvURL(from: directoryURL, sheetName: "공개 목록")
            var request = URLRequest(url: url); request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count <= 1_000_000, let raw = String(data: data, encoding: .utf8) else {
                throw ImportFailure.invalid("공개 목록을 읽을 수 없습니다.")
            }
            let rows = try LibraryImporter.parseCSV(raw.replacingOccurrences(of: "\u{FEFF}", with: ""))
            guard let header = rows.first, header.count >= 5,
                  header[0] == "라이브러리 그룹 이름", header[1] == "Google Sheets 링크",
                  header[2] == "상태", header[3] == "설명", header[4] == "닉네임" else {
                throw ImportFailure.invalid("공개 목록의 열을 확인해 주세요.")
            }
            publicEntries = rows.dropFirst().compactMap { row in
                guard row.count >= 5, row[2].uppercased() == "TRUE", !row[0].isEmpty,
                      (try? SheetURL.manifestURL(from: row[1])) != nil else { return nil }
                return PublicDirectoryEntry(name: row[0], link: row[1],
                                            description: row[3], nickname: row[4])
            }
            publicDirectoryError = nil
        } catch { publicDirectoryError = error.localizedDescription }
    }
    func registerSheetLink(_ link: String) {
        guard let normalized = try? SheetURL.manifestURL(from: link),
              let components = URLComponents(url: normalized, resolvingAgainstBaseURL: false),
              let identifier = components.path.split(separator: "/").last else { return }
        let canonical = "https://docs.google.com/spreadsheets/d/\(identifier)/edit"
        if !sheetLinks.contains(canonical) { archive.sheetLinks = (archive.sheetLinks ?? []) + [canonical]; save() }
    }
    func removeSheetLink(_ link: String) {
        archive.sheetLinks?.removeAll { $0 == link }; save()
    }
    var haptics = true
    private let location: URL
    private var storageReadable = true
    var reviewDepthCount: Int {
        get { archive.configuredReviewDepthCount }
        set { archive.reviewDepthCount = min(20, max(highestUsedReviewDepth, max(3, newValue))); save() }
    }
    var highestUsedReviewDepth: Int {
        max(3, (archive.reviewDepthStacks ?? []).enumerated().filter { !$0.element.words.isEmpty }.map { $0.offset + 1 }.max() ?? 3)
    }
    var reviewDepthStacks: [Stack] { Array((archive.reviewDepthStacks ?? []).prefix(reviewDepthCount)) }
    var completedReviewWords: [Word] { archive.completedReviewWords ?? [] }
    var poolSize: Int {
        get { min(100, max(1, archive.studyPoolSize ?? Stack.poolLimit)) }
        set {
            archive.studyPoolSize = min(100, max(1, newValue))
            for i in archive.stacks.indices { archive.stacks[i].prepare(poolSize: poolSize) }
            if archive.reviewDepthStacks != nil {
                for i in archive.reviewDepthStacks!.indices { archive.reviewDepthStacks![i].prepare(poolSize: poolSize) }
            }
            save()
        }
    }
    var dailyStudyLimitEnabled: Bool {
        get { archive.dailyStudyLimitEnabled ?? true }
        set { archive.dailyStudyLimitEnabled = newValue; save() }
    }
    var dailyStudyLimit: Int {
        get { min(10_000, max(1, archive.dailyStudyLimit ?? 100)) }
        set { archive.dailyStudyLimit = min(10_000, max(1, newValue)); save() }
    }
    private func resetDailyStudyIfNeeded(now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        guard archive.dailyStudyDay != today else { return }
        archive.dailyStudyDay = today
        archive.dailyStudyDisplays = 0
        archive.dailyStudySeenItems = []
        archive.dailyStudyUnlimitedToday = false
        save()
    }
    var dailyStudyDisplays: Int {
        archive.dailyStudyDay == Calendar.current.startOfDay(for: Date()) ? (archive.dailyStudyDisplays ?? 0) : 0
    }
    var dailyStudyCapReached: Bool {
        dailyStudyLimitEnabled && !(archive.dailyStudyDay == Calendar.current.startOfDay(for: Date()) && archive.dailyStudyUnlimitedToday == true) && dailyStudyDisplays >= dailyStudyLimit
    }
    var dailyStudySeenItems: Set<ReviewItem> {
        archive.dailyStudyDay == Calendar.current.startOfDay(for: Date()) ? (archive.dailyStudySeenItems ?? []) : []
    }
    func recordStudyDisplay(_ item: ReviewItem) {
        resetDailyStudyIfNeeded()
        archive.dailyStudySeenItems = (archive.dailyStudySeenItems ?? []).union([item])
        archive.dailyStudyDisplays = (archive.dailyStudyDisplays ?? 0) + 1
        save()
    }
    func allowMoreStudyToday() {
        resetDailyStudyIfNeeded()
        archive.dailyStudyUnlimitedToday = true
        save()
    }
    var oneWayStudy: Bool {
        get { archive.oneWayStudy ?? false }
        set { archive.oneWayStudy = newValue; for i in archive.stacks.indices { archive.stacks[i].oneWay = newValue; archive.stacks[i].prepare(poolSize: poolSize) }; save() }
    }
    var reviewWaitMinutes: Int {
        get { archive.reviewWaitMinutes ?? 1440 }
        set { archive.reviewWaitMinutes = newValue; save() }
    }
    var kanaStudyMode: Bool {
        get { archive.kanaStudyMode ?? false }
        set { archive.kanaStudyMode = newValue; save() }
    }
    var showReadingOnFront: Bool {
        get { archive.showReadingOnFront ?? true }
        set {
            archive.showReadingOnFront = newValue
            save()
        }
    }
    init() {
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.arguments.contains("--uitesting-resume")
        location = testing ? URL.temporaryDirectory.appending(path: "voca-ui-tests.json") : URL.documentsDirectory.appending(path: "voca-data.json")
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { try? FileManager.default.removeItem(at: location) }
        #else
        location = URL.documentsDirectory.appending(path: "voca-data.json")
        #endif
        do {
            if FileManager.default.fileExists(atPath: location.path) {
                archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: location))
            } else { archive = .sample }
        } catch {
            archive = Archive()
            storageReadable = false
            self.error = "저장된 데이터를 읽지 못했습니다. 원본 파일은 유지됩니다. 앱을 다시 실행해 주세요. \(error.localizedDescription)"
        }
        haptics = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
        let needsReviewDepths = archive.reviewDepthStacks == nil || (archive.reviewDepthStacks?.count ?? 0) < 20
        archive.prepareReviewDepths()
        let removedExamples = archive.removeLegacyExamples()
        let needsGroupedLibrary = !archive.server.contains { $0.id == GroupedExpressions.libraryID }
        if needsGroupedLibrary { archive.server.append(GroupedExpressions.library) }
        if removedExamples || needsGroupedLibrary || needsReviewDepths { save() }

    }
    func save() {
        guard storageReadable else { error = "원본 데이터 보호를 위해 저장을 중단했습니다. 앱을 다시 실행해 주세요."; return }
        do { try JSONEncoder().encode(archive).write(to: location, options: .atomic) }
        catch { self.error = "저장하지 못했습니다: \(error.localizedDescription)" }
    }
    func update(_ stack: Stack) {
        guard let i = archive.stacks.firstIndex(where: { $0.id == stack.id }) else { return }
        archive.stacks[i] = stack; save()
    }
    func reviewDepthStack(at depth: Int) -> Stack? {
        guard (1...reviewDepthCount).contains(depth), let depths = archive.reviewDepthStacks, depths.indices.contains(depth - 1) else { return nil }
        return depths[depth - 1]
    }
    func updateReviewDepthStack(_ stack: Stack, at depth: Int) {
        guard (1...reviewDepthCount).contains(depth), archive.reviewDepthStacks?.indices.contains(depth - 1) == true,
              archive.reviewDepthStacks![depth - 1].id == stack.id else { return }
        archive.reviewDepthStacks![depth - 1] = stack
        save()
    }
    @discardableResult func addToReviewDepth(_ word: Word, at depth: Int) -> Bool {
        let added = archive.addToReviewDepth(word, at: depth, poolSize: poolSize)
        if added { save() }
        return added
    }
    @discardableResult func moveToReviewDepth(_ word: Word, from sourceDepth: Int) -> Bool {
        let moved = archive.moveToReviewDepth(word, from: sourceDepth, poolSize: poolSize)
        if moved { save() }
        return moved
    }
    func advanceReviewDepthWord(_ word: Word, updatedSource: Stack, from sourceDepth: Int) -> ReviewDepthAdvanceSnapshot? {
        guard archive.reviewDepthStacks?.indices.contains(sourceDepth - 1) == true else { return nil }
        let destinationDepth = sourceDepth < reviewDepthCount ? sourceDepth + 1 : nil
        let previousDestination = destinationDepth.flatMap { reviewDepthStack(at: $0) }
        let previousCompleted = archive.completedReviewWords ?? []
        archive.reviewDepthStacks![sourceDepth - 1] = updatedSource
        guard archive.advanceReviewDepthWord(word, from: sourceDepth, poolSize: poolSize) else { return nil }
        save()
        return ReviewDepthAdvanceSnapshot(sourceDepth: sourceDepth, previousDestination: previousDestination,
                                          destinationDepth: destinationDepth, previousCompleted: previousCompleted)
    }
    func undoReviewDepthAdvance(_ snapshot: ReviewDepthAdvanceSnapshot, restore source: Stack) {
        guard archive.reviewDepthStacks?.indices.contains(snapshot.sourceDepth - 1) == true else { return }
        archive.reviewDepthStacks![snapshot.sourceDepth - 1] = source
        if let destination = snapshot.previousDestination, let depth = snapshot.destinationDepth,
           archive.reviewDepthStacks!.indices.contains(depth - 1) {
            archive.reviewDepthStacks![depth - 1] = destination
        }
        archive.completedReviewWords = snapshot.previousCompleted
        save()
    }
    func removeCompletedReviewWord(_ wordID: UUID) {
        archive.completedReviewWords?.removeAll { $0.id == wordID }
        save()
    }
    func restoreReviewDepths(source: Stack?, sourceDepth: Int?, destination: Stack, destinationDepth: Int) {
        guard archive.reviewDepthStacks?.indices.contains(destinationDepth - 1) == true else { return }
        archive.reviewDepthStacks![destinationDepth - 1] = destination
        if let source, let sourceDepth, archive.reviewDepthStacks!.indices.contains(sourceDepth - 1) {
            archive.reviewDepthStacks![sourceDepth - 1] = source
        }
        save()
    }
    func removeReviewDepthWord(_ wordID: UUID, at depth: Int) {
        guard (1...reviewDepthCount).contains(depth), archive.reviewDepthStacks?.indices.contains(depth - 1) == true else { return }
        archive.reviewDepthStacks![depth - 1].words.removeAll { $0.id == wordID }
        archive.reviewReadyAt?.removeValue(forKey: wordID)
        archive.reviewDepthStacks![depth - 1].prepare(poolSize: poolSize)
        save()
    }
    func restartReviewDepth(at depth: Int) -> Bool {
        guard (1...reviewDepthCount).contains(depth), archive.reviewDepthStacks?.indices.contains(depth - 1) == true,
              !archive.reviewDepthStacks![depth - 1].words.isEmpty else { return false }
        archive.reviewDepthStacks![depth - 1].reset(poolSize: poolSize)
        save()
        return true
    }
    @discardableResult
    func restartStack(_ stackID: UUID) -> Bool {
        guard let i = archive.stacks.firstIndex(where: { $0.id == stackID }),
              !archive.stacks[i].words.isEmpty else { return false }
        // Reset the local copy so removed cards stay removed and corrections are retained.
        archive.stacks[i].oneWay = oneWayStudy
        archive.stacks[i].reset(poolSize: poolSize)
        save()
        return true
    }
    func recordMeaningCorrection(library: Library?, stack: Stack, word: Word, correctedKorean: String) {
        guard storageReadable else { error = "원본 데이터 보호를 위해 제보 저장을 중단했습니다. 앱을 다시 실행해 주세요."; return }
        archive.recordMeaningCorrection(library: library, stack: stack, word: word, correctedKorean: correctedKorean)
        save()
    }
    func removeWord(_ wordID: UUID, from stackID: UUID) {
        guard let i = archive.stacks.firstIndex(where: { $0.id == stackID }) else { return }
        archive.stacks[i].words.removeAll { $0.id == wordID }
        archive.stacks[i].prepare(poolSize: poolSize)
        save()
    }
    func removeStack(_ stackID: UUID) {
        archive.stacks.removeAll { $0.id == stackID }
        save()
    }
    func removeAllStacks() {
        archive.stacks = []
        save()
    }
    func removeLibrary(_ libraryID: UUID) {
        archive.libraries.removeAll { $0.id == libraryID }
        save()
    }
    func enroll(_ stack: Stack) {
        guard !isEnrolled(stack) else { return }
        var copy = Stack(title: stack.title, words: stack.words, sourceID: stack.id)
        copy.oneWay = oneWayStudy
        copy.prepare(poolSize: poolSize); archive.stacks.append(copy); save()
    }
    func isEnrolled(_ stack: Stack) -> Bool { archive.stacks.contains { $0.sourceID == stack.id || $0.id == stack.id } }
    func search(_ text: String, using provider: SearchProvider) {
        let template = provider.template.trimmingCharacters(in: .whitespacesAndNewlines)
        let marker = "VOCASERCHPLACEHOLDER"
        guard template.contains("{query}"),
              var components = URLComponents(string: template.replacingOccurrences(of: "{query}", with: marker)),
              let queryItems = components.queryItems,
              queryItems.contains(where: { ($0.name + ($0.value ?? "")).contains(marker) }) else {
            error = "검색 주소에 {query}가 있는지 확인해 주세요. 설정의 검색 버튼 설정에서 수정할 수 있습니다."
            return
        }
        components.queryItems = queryItems.map { item in
            URLQueryItem(name: item.name.replacingOccurrences(of: marker, with: text),
                         value: item.value?.replacingOccurrences(of: marker, with: text))
        }
        guard let url = components.url,
              url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else {
            error = "검색 주소는 https://로 시작하고 검색어 자리인 {query}를 포함해야 합니다. 설정의 검색 설정에서 확인해 주세요."
            return
        }
        openSearchURL(url)
    }
    private func openSearchURL(_ webURL: URL) {
        guard var chrome = URLComponents(url: webURL, resolvingAgainstBaseURL: false) else { return }
        chrome.scheme = "googlechromes"
        guard let chromeURL = chrome.url else { return }
        UIApplication.shared.open(chromeURL, options: [:]) { opened in
            if !opened { UIApplication.shared.open(webURL) }
        }
    }
    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
}
