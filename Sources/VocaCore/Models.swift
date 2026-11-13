import Foundation

public struct Word: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var japanese: String
    public var korean: String
    public var example: String
    public var normalizedReading: String? {
        guard let value = reading?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !["-", "—", "–", "－"].contains(value) else { return nil }
        return value
    }
    public var kanaText: String { normalizedReading ?? japanese }
    public var reading: String?
    public var source: String?
    public var license: String?
    public var exampleSource: String?
    public var translationStatus: String?
    public var isSentence: Bool?
    public var sourceLanguageCode: String?
    public var targetLanguageCode: String?
    public var translations: [String: String]?
    public var externalCardID: String?
    public var sourceLanguageName: String { Locale(identifier: "ko_KR").localizedString(forLanguageCode: sourceLanguageCode?.split(separator: "-").first.map(String.init) ?? "ja") ?? "일본어" }
    public var targetLanguageName: String { Locale(identifier: "ko_KR").localizedString(forLanguageCode: targetLanguageCode?.split(separator: "-").first.map(String.init) ?? "ko") ?? "한국어" }
    public init(id: UUID = UUID(), japanese: String, korean: String, example: String) {
        self.id = id; self.japanese = japanese; self.korean = korean; self.example = example
    }
}
public enum Direction: String, Codable, CaseIterable, Sendable {
    case japaneseToKorean, koreanToJapanese
    public var label: String { self == .japaneseToKorean ? "일본어 → 한국어" : "한국어 → 일본어" }
}
public struct ReviewItem: Codable, Equatable, Hashable, Sendable {
    public var wordID: UUID
    public var direction: Direction
    public init(wordID: UUID, direction: Direction) { self.wordID = wordID; self.direction = direction }
}
public struct Stack: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var words: [Word]
    public var mastered: Set<ReviewItem>
    public var queue: [ReviewItem]
    public var sourceID: UUID?
    public var externalStackID: String?
    public var recentWordIDs: [UUID]?
    public var hasShuffledQueue: Bool?
    public var oneWay: Bool?
    public static let poolLimit = 20
    public var remainingCount: Int { allItems.filter { !mastered.contains($0) }.count }
    public init(id: UUID = UUID(), title: String, words: [Word] = [], sourceID: UUID? = nil) {
        self.id = id; self.title = title; self.words = words; self.mastered = []; self.queue = []; self.sourceID = sourceID
    }
    public var allItems: [ReviewItem] {
        Direction.allCases.flatMap { direction in words.compactMap {
            direction == .koreanToJapanese && (oneWay == true || $0.isSentence == true) ? nil : ReviewItem(wordID: $0.id, direction: direction)
        } }
    }
    public var isComplete: Bool { !words.isEmpty && allItems.allSatisfy { mastered.contains($0) } }
    public var progress: Double { allItems.isEmpty ? 0 : Double(allItems.filter { mastered.contains($0) }.count) / Double(allItems.count) }
    public mutating func prepare(poolSize: Int = Self.poolLimit) {
        let valid = Set(allItems)
        mastered.formIntersection(valid)
        var seenWords = Set<UUID>()
        queue = Array(queue.filter {
            valid.contains($0) && !mastered.contains($0) && seenWords.insert($0.wordID).inserted
        }.prefix(max(1, poolSize)))
        // Older saved queues were ordered by the source sheet. Shuffle once when migrating.
        if hasShuffledQueue != true { queue.shuffle(); hasShuffledQueue = true }
        if recentWordIDs == nil { recentWordIDs = [] }
        refill(poolSize: max(1, poolSize))
    }
    public mutating func prepareReviewDepth(poolSize: Int = Self.poolLimit) {
        let valid = Set(words.map { ReviewItem(wordID: $0.id, direction: .japaneseToKorean) })
        mastered.formIntersection(valid)
        var seen = Set<UUID>()
        queue = Array(queue.filter {
            valid.contains($0) && !mastered.contains($0) && seen.insert($0.wordID).inserted
        }.prefix(max(1, poolSize)))
        if hasShuffledQueue != true { queue.shuffle(); hasShuffledQueue = true }
        if recentWordIDs == nil { recentWordIDs = [] }
        refillReviewDepth(poolSize: max(1, poolSize))
    }
    public mutating func answerReviewSession(known: Bool, poolSize: Int = Self.poolLimit) {
        guard let current = queue.first else { return }
        if known {
            words.removeAll { $0.id == current.wordID }
            prepareReviewDepth(poolSize: poolSize)
        } else {
            queue.removeFirst()
            queue.insert(current, at: Int.random(in: min(3, queue.count)...queue.count))
        }
    }
    private mutating func refillReviewDepth(poolSize: Int) {
        var active = Set(queue.map(\.wordID))
        let recent = recentWordIDs ?? []
        while queue.count < poolSize {
            let candidates = words
                .map { ReviewItem(wordID: $0.id, direction: .japaneseToKorean) }
                .filter { !mastered.contains($0) && !active.contains($0.wordID) }
            guard !candidates.isEmpty else { break }
            let oldest = candidates.map { recent.firstIndex(of: $0.wordID) ?? -1 }.min() ?? -1
            guard let next = candidates.filter({ (recent.firstIndex(of: $0.wordID) ?? -1) == oldest }).randomElement() else { break }
            active.insert(next.wordID)
            queue.insert(next, at: Int.random(in: min(3, queue.count)...queue.count))
        }
    }
    private mutating func refill(poolSize: Int) {
        var activeWords = Set(queue.map(\.wordID))
        let recent = recentWordIDs ?? []
        while queue.count < poolSize {
            let pending = allItems.filter { !mastered.contains($0) && !activeWords.contains($0.wordID) }
            guard !pending.isEmpty else { break }
            // Prefer unseen Japanese fronts. When only reverse cards remain, use the
            // oldest answered word first so a just-answered word waits longest.
            let fronts = pending.filter { $0.direction == .japaneseToKorean }
            let candidates = fronts.isEmpty ? pending : fronts
            let oldest = candidates.map { recent.firstIndex(of: $0.wordID) ?? -1 }.min() ?? -1
            guard let next = candidates.filter({ (recent.firstIndex(of: $0.wordID) ?? -1) == oldest }).randomElement() else { break }
            activeWords.insert(next.wordID)
            // A replacement may enter the pool immediately, but cannot become
            // the next or second-next card while enough other cards exist.
            let firstSlot = min(3, queue.count)
            let lastSlot = queue.count
            queue.insert(next, at: Int.random(in: firstSlot...lastSlot))
        }
    }
    public mutating func answer(known: Bool, poolSize: Int = Self.poolLimit) {
        guard !queue.isEmpty else { return }
        let current = queue.removeFirst()
        if known {
            mastered.insert(current)
            var recent = (recentWordIDs ?? []).filter { $0 != current.wordID }
            recent.append(current.wordID)
            recentWordIDs = Array(recent.suffix(max(1, poolSize)))
            refill(poolSize: max(1, poolSize))
        } else {
            // Retry only within the current pool; an incorrect answer never admits a new word.
            queue.insert(current, at: Int.random(in: min(3, queue.count)...queue.count))
        }
    }
    public mutating func reset(poolSize: Int = Self.poolLimit) { mastered = []; queue = []; recentWordIDs = []; hasShuffledQueue = nil; prepare(poolSize: poolSize) }

    public mutating func restrictToSeen(_ seen: Set<ReviewItem>, poolSize: Int) {
        queue.removeAll { !seen.contains($0) }
        var active = Set(queue.map(\.wordID))
        for item in allItems.filter({ seen.contains($0) && !mastered.contains($0) }).shuffled() {
            guard queue.count < poolSize else { break }
            if active.insert(item.wordID).inserted { queue.append(item) }
        }
    }

    public mutating func remapWordIDs(_ ids: [UUID: UUID]) {
        guard !ids.isEmpty else { return }
        for index in words.indices { words[index].id = ids[words[index].id] ?? words[index].id }
        mastered = Set(mastered.map { ReviewItem(wordID: ids[$0.wordID] ?? $0.wordID, direction: $0.direction) })
        queue = queue.map { ReviewItem(wordID: ids[$0.wordID] ?? $0.wordID, direction: $0.direction) }
        recentWordIDs = recentWordIDs?.map { ids[$0] ?? $0 }
    }

}
public struct Library: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var stacks: [Stack]
    public init(id: UUID = UUID(), title: String, subtitle: String = "직접 만든 단어 모음", stacks: [Stack] = []) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.stacks = stacks
    }
    public var wordCount: Int { stacks.reduce(0) { $0 + $1.words.count } }
    public var isSentenceDeck: Bool { !stacks.isEmpty && stacks.flatMap(\.words).allSatisfy { $0.isSentence == true } }
}
public struct Archive: Codable, Sendable {
    public var sheetLinks: [String]?
    public var studyPoolSize: Int?
    public var reviewPoolSize: Int?
    public var dailyStudyLimitEnabled: Bool?
    public var dailyStudyLimit: Int?
    public var dailyStudyDay: Date?
    public var dailyStudyDisplays: Int?
    public var dailyStudySeenItems: Set<ReviewItem>?
    public var dailyStudyUnlimitedToday: Bool?
    public var oneWayStudy: Bool?
    public var reviewWaitMinutes: Int?
    public var reviewReadyAt: [UUID: Date]?
    public var kanaStudyMode: Bool?
    public var reviewDepthCount: Int?
    public var reviewDepthStacks: [Stack]?
    public var completedReviewWords: [Word]?
    public var microSessionCardCount: Int?
    public var showReadingOnFront: Bool?
    public var wordReports: [WordReport]?
    public var microReviewSettings: MicroReviewSettings?
    public var microReviewEntries: [MicroReviewEntry]?
    public var stacks: [Stack]
    public var libraries: [Library]
    public var server: [Library]
    public init(stacks: [Stack] = [], libraries: [Library] = [], server: [Library] = []) {
        self.stacks = stacks; self.libraries = libraries; self.server = server
    }
    public mutating func installImportedLibrary(_ imported: Library) {
        if let index = libraries.firstIndex(where: { $0.id == imported.id }) {
            let previous = libraries[index]
            var updated = imported
            for oldStack in previous.stacks {
                guard let newStackIndex = imported.stacks.firstIndex(where: {
                    $0.id == oldStack.id || $0.externalStackID == oldStack.externalStackID ||
                    ($0.externalStackID.flatMap(UUID.init(uuidString:)) == oldStack.id)
                }) else { continue }
                let newStack = imported.stacks[newStackIndex]
                var ids: [UUID: UUID] = [:]
                for oldWord in oldStack.words {
                    if let newWordIndex = newStack.words.firstIndex(where: {
                        $0.id == oldWord.id || $0.externalCardID == oldWord.externalCardID && oldWord.externalCardID != nil ||
                        ($0.externalCardID.flatMap(UUID.init(uuidString:)) == oldWord.id)
                    }) {
                        ids[oldWord.id] = newStack.words[newWordIndex].id
                        if let correction = wordReports?.reversed().first(where: {
                            $0.libraryID == imported.id && $0.stackID == oldStack.id &&
                            $0.word.id == oldWord.id && $0.correctedKorean != nil
                        })?.correctedKorean {
                            updated.stacks[newStackIndex].words[newWordIndex].korean = correction
                        }
                    }
                }
                for localIndex in stacks.indices where stacks[localIndex].sourceID == oldStack.id {
                    stacks[localIndex].sourceID = newStack.id
                    stacks[localIndex].remapWordIDs(ids)
                }
                let unambiguousIDs = ids.filter { oldID, _ in
                    libraries.flatMap(\.stacks).flatMap(\.words).filter { $0.id == oldID }.count == 1
                }
                for depthIndex in (reviewDepthStacks ?? []).indices {
                    reviewDepthStacks?[depthIndex].remapWordIDs(unambiguousIDs)
                }
                completedReviewWords = completedReviewWords?.map { word in
                    var updated = word
                    updated.id = unambiguousIDs[word.id] ?? word.id
                    return updated
                }
                if let ready = reviewReadyAt {
                    reviewReadyAt = Dictionary(ready.map { (unambiguousIDs[$0.key] ?? $0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
                }
            }
            libraries[index] = updated
        } else { libraries.append(imported) }
    }
    public func reviewDepth(of id: UUID) -> Int? {
        reviewDepthStacks?.firstIndex(where: { $0.words.contains(where: { $0.id == id }) }).map { $0 + 1 }
    }
    public func reviewSession(poolSize: Int = Stack.poolLimit, now: Date = Date()) -> Stack {
        var seen = Set<UUID>()
        let words = (reviewDepthStacks ?? []).prefix(configuredReviewDepthCount).flatMap(\.words).filter {
            seen.insert($0.id).inserted && (reviewReadyAt?[$0.id] ?? .distantPast) <= now
        }
        var session = Stack(title: "반복 학습", words: words)
        session.prepareReviewDepth(poolSize: poolSize)
        return session
    }
    public var configuredReviewDepthCount: Int { min(20, max(3, reviewDepthCount ?? 5)) }
    public mutating func prepareReviewDepths() {
        var depths = reviewDepthStacks ?? []
        while depths.count < 20 { depths.append(Stack(title: "\(depths.count + 1)단계 단어")) }
        var seen = Set((completedReviewWords ?? []).map(\.id))
        for index in depths.indices.reversed() {
            depths[index].words = depths[index].words.filter { seen.insert($0.id).inserted }
        }
        reviewDepthStacks = depths
    }
    @discardableResult public mutating func addToReviewDepth(_ word: Word, at depth: Int, poolSize: Int = Stack.poolLimit) -> Bool {
        guard (1...configuredReviewDepthCount).contains(depth) else { return false }
        prepareReviewDepths()
        guard !(reviewDepthStacks ?? []).contains(where: { $0.words.contains(where: { $0.id == word.id }) }), !(completedReviewWords ?? []).contains(where: { $0.id == word.id }) else { return false }
        reviewDepthStacks![depth - 1].words.append(word)
        reviewDepthStacks![depth - 1].prepare(poolSize: poolSize)
        return true
    }
    @discardableResult public mutating func moveToReviewDepth(_ word: Word, from sourceDepth: Int, poolSize: Int = Stack.poolLimit) -> Bool {
        let destinationDepth = sourceDepth + 1
        guard sourceDepth >= 1, destinationDepth <= configuredReviewDepthCount,
              reviewDepthStacks?.indices.contains(sourceDepth - 1) == true,
              reviewDepthStacks![sourceDepth - 1].words.contains(where: { $0.id == word.id }) else { return false }
        prepareReviewDepths()
        if let existing = reviewDepthStacks![destinationDepth - 1].words.firstIndex(where: { $0.id == word.id }) {
            reviewDepthStacks![destinationDepth - 1].words[existing] = word
        } else {
            reviewDepthStacks![destinationDepth - 1].words.append(word)
        }
        reviewDepthStacks![destinationDepth - 1].prepare(poolSize: poolSize)
        reviewDepthStacks![sourceDepth - 1].words.removeAll { $0.id == word.id }
        reviewDepthStacks![sourceDepth - 1].prepare(poolSize: poolSize)
        return true
    }
    @discardableResult public mutating func advanceReviewDepthWord(_ word: Word, from sourceDepth: Int, poolSize: Int = Stack.poolLimit,
                                                                 waitMinutes: Int? = nil, now: Date = Date()) -> Bool {
        guard sourceDepth >= 1, sourceDepth <= configuredReviewDepthCount,
              reviewDepthStacks?.indices.contains(sourceDepth - 1) == true,
              reviewDepthStacks![sourceDepth - 1].words.contains(where: { $0.id == word.id }) else { return false }
        if sourceDepth < configuredReviewDepthCount {
            prepareReviewDepths()
            let next = sourceDepth
            if let existing = reviewDepthStacks![next].words.firstIndex(where: { $0.id == word.id }) {
                reviewDepthStacks![next].words[existing] = word
            } else {
                reviewDepthStacks![next].words.append(word)
            }
            reviewDepthStacks![next].prepare(poolSize: poolSize)
        } else {
            var completed = completedReviewWords ?? []
            if let existing = completed.firstIndex(where: { $0.id == word.id }) { completed[existing] = word }
            else { completed.append(word) }
            completedReviewWords = completed
        }
        reviewDepthStacks![sourceDepth - 1].words.removeAll { $0.id == word.id }
        reviewDepthStacks![sourceDepth - 1].prepare(poolSize: poolSize)
        let minutes = waitMinutes ?? reviewWaitMinutes ?? 1_440
        if sourceDepth < configuredReviewDepthCount, minutes > 0 {
            reviewReadyAt = reviewReadyAt ?? [:]
            reviewReadyAt?[word.id] = Self.nextReviewBoundary(after: now, minutes: minutes)
        } else { reviewReadyAt?.removeValue(forKey: word.id) }
        return true
    }
    public static func nextReviewBoundary(after date: Date, minutes: Int, calendar: Calendar = .current) -> Date {
        guard minutes > 0 else { return date }
        if minutes >= 10_080 {
            let days = minutes / 1_440
            return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date))
                ?? date.addingTimeInterval(Double(minutes * 60))
        }
        let day = calendar.startOfDay(for: date)
        if minutes >= 1_440 {
            let anchor = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? day
            let elapsedDays = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
            let span = max(1, minutes / 1_440)
            let nextDay = ((elapsedDays / span) + 1) * span
            return calendar.date(byAdding: .day, value: nextDay, to: anchor) ?? date.addingTimeInterval(Double(minutes * 60))
        }
        let elapsed = max(0, calendar.dateComponents([.minute], from: day, to: date).minute ?? 0)
        let next = (elapsed / minutes + 1) * minutes
        return calendar.date(byAdding: .minute, value: next, to: day) ?? date.addingTimeInterval(Double(minutes * 60))
    }
    @discardableResult public mutating func removeLegacyExamples() -> Bool {
        var changed = false
        func clear(_ word: inout Word) {
            if !word.example.isEmpty { word.example = ""; changed = true }
            if word.exampleSource != nil { changed = true }
            word.exampleSource = nil
        }
        for stackIndex in stacks.indices {
            for wordIndex in stacks[stackIndex].words.indices { clear(&stacks[stackIndex].words[wordIndex]) }
        }
        if reviewDepthStacks != nil {
            for stackIndex in reviewDepthStacks!.indices {
                for wordIndex in reviewDepthStacks![stackIndex].words.indices { clear(&reviewDepthStacks![stackIndex].words[wordIndex]) }
            }
        }
        if completedReviewWords != nil {
            for index in completedReviewWords!.indices { clear(&completedReviewWords![index]) }
        }
        for libraryIndex in libraries.indices {
            for stackIndex in libraries[libraryIndex].stacks.indices {
                for wordIndex in libraries[libraryIndex].stacks[stackIndex].words.indices {
                    clear(&libraries[libraryIndex].stacks[stackIndex].words[wordIndex])
                }
            }
        }
        for libraryIndex in server.indices {
            for stackIndex in server[libraryIndex].stacks.indices {
                for wordIndex in server[libraryIndex].stacks[stackIndex].words.indices {
                    clear(&server[libraryIndex].stacks[stackIndex].words[wordIndex])
                }
            }
        }
        if microReviewEntries != nil {
            for index in microReviewEntries!.indices { clear(&microReviewEntries![index].word) }
        }
        if wordReports != nil {
            for index in wordReports!.indices { clear(&wordReports![index].word) }
        }
        return changed
    }
    @discardableResult public mutating func recordMeaningCorrection(library: Library?, stack: Stack, word: Word, correctedKorean: String) -> Bool {
        let correction = correctedKorean.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !correction.isEmpty else { return false }
        let report = WordReport(library: library, stack: stack, word: word, correctedKorean: correction)
        wordReports = (wordReports ?? []) + [report]
        var updatedMyCard = false
        if let libraryIndex = libraries.firstIndex(where: { $0.id == library?.id }),
           let stackIndex = libraries[libraryIndex].stacks.firstIndex(where: { $0.id == (stack.sourceID ?? stack.id) || $0.id == stack.id }),
           let wordIndex = libraries[libraryIndex].stacks[stackIndex].words.firstIndex(where: { $0.id == word.id }) {
            libraries[libraryIndex].stacks[stackIndex].words[wordIndex].korean = correction
            updatedMyCard = true
        }
        for stackIndex in stacks.indices where stacks[stackIndex].id == stack.id || stacks[stackIndex].sourceID == stack.id {
            guard let wordIndex = stacks[stackIndex].words.firstIndex(where: { $0.id == word.id }) else { continue }
            stacks[stackIndex].words[wordIndex].korean = correction
            updatedMyCard = true
        }
        if reviewDepthStacks != nil {
            for stackIndex in reviewDepthStacks!.indices {
                guard let wordIndex = reviewDepthStacks![stackIndex].words.firstIndex(where: { $0.id == word.id }) else { continue }
                reviewDepthStacks![stackIndex].words[wordIndex].korean = correction
                updatedMyCard = true
            }
        }
        if completedReviewWords != nil {
            for index in completedReviewWords!.indices where completedReviewWords![index].id == word.id {
                completedReviewWords![index].korean = correction
                updatedMyCard = true
            }
        }
        if var entries = microReviewEntries {
            for index in entries.indices where entries[index].word.id == word.id {
                entries[index].word.korean = correction
            }
            microReviewEntries = entries
        }
        return updatedMyCard
    }
    public static var sample: Archive {
        let daily = Stack(title: "하루를 시작하는 말", words: [
            Word(japanese: "おはようございます", korean: "좋은 아침이에요", example: ""),
            Word(japanese: "楽しみ", korean: "기대, 즐거움", example: ""),
            Word(japanese: "散歩", korean: "산책", example: ""),
            Word(japanese: "ゆっくり", korean: "천천히, 느긋하게", example: "")])
        let travel = Stack(title: "카페에서", words: [
            Word(japanese: "おすすめ", korean: "추천", example: ""),
            Word(japanese: "持ち帰り", korean: "포장, 테이크아웃", example: "")])
        return Archive(stacks: [daily], server: [Library(title: "작은 일본어 생활", subtitle: "매일 만나는 표현부터, 가볍게", stacks: [daily, travel]), GroupedExpressions.library])
    }
}

// Legacy save format only; no notification or review behavior.
public struct MicroReviewSettings: Codable, Equatable, Sendable {
    public var usesSystemAlarm: Bool?
    public var enabled = false
    public var intervalMinutes = 60
    public var startHour = 10
    public var endHour = 20
    public var includesWeekends = true
    public init() {}

}

public enum MicroReviewStatus: String, Codable, Sendable { case active, completed, stopped }

public struct MicroReviewEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var word: Word
    public var sourceTitle: String
    public var successCount: Int
    public var status: MicroReviewStatus
    public var addedAt: Date
    public var lastReviewedAt: Date?

    public init(word: Word, sourceTitle: String, addedAt: Date = Date()) {
        id = UUID(); self.word = word; self.sourceTitle = sourceTitle
        successCount = 0; status = .active; self.addedAt = addedAt
    }
}

public struct WordReport: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var createdAt = Date()
    public var libraryID: UUID?
    public var libraryTitle: String?
    public var stackID: UUID
    public var stackTitle: String
    public var word: Word
    public var message: String
    public var correctedKorean: String?
    public init(library: Library?, stack: Stack, word: Word, message: String) {
        libraryID = library?.id; libraryTitle = library?.title
        stackID = stack.sourceID ?? stack.id; stackTitle = stack.title
        self.word = word; self.message = message
    }
    public init(library: Library?, stack: Stack, word: Word, correctedKorean: String) {
        self.init(library: library, stack: stack, word: word, message: correctedKorean)
        self.correctedKorean = correctedKorean
    }
    public var shareText: String {
        "카드 뜻 수정 내용\n라이브러리: \(libraryTitle ?? "내 스택")\n스택: \(stackTitle)\n일본어: \(word.japanese)\n읽기: \(word.reading ?? "")\n기존 한국어 뜻: \(word.korean)\n\(correctedKorean.map { "수정한 한국어 뜻: \($0)" } ?? "메모: \(message)")\n단어 ID: \(word.id)\n스택 ID: \(stackID)\n출처: \(word.source ?? "직접 등록")"
    }
}


public enum GroupedExpressions {
    public static let libraryID = LibraryImporter.stableID("voca:built-in:grouped-expressions:v1")

    public static var library: Library {
        let stacks = [
            stack("요일", [
                ("月曜日", "げつようび", "월요일"), ("火曜日", "かようび", "화요일"),
                ("水曜日", "すいようび", "수요일"), ("木曜日", "もくようび", "목요일"),
                ("金曜日", "きんようび", "금요일"), ("土曜日", "どようび", "토요일"),
                ("日曜日", "にちようび", "일요일")
            ]),
            stack("월 · 1~12월", [
                ("一月", "いちがつ", "1월"), ("二月", "にがつ", "2월"),
                ("三月", "さんがつ", "3월"), ("四月", "しがつ", "4월"),
                ("五月", "ごがつ", "5월"), ("六月", "ろくがつ", "6월"),
                ("七月", "しちがつ", "7월"), ("八月", "はちがつ", "8월"),
                ("九月", "くがつ", "9월"), ("十月", "じゅうがつ", "10월"),
                ("十一月", "じゅういちがつ", "11월"), ("十二月", "じゅうにがつ", "12월")
            ]),
            stack("날짜 · 1~16일", Array(zip(
                ["一日","二日","三日","四日","五日","六日","七日","八日","九日","十日","十一日","十二日","十三日","十四日","十五日","十六日"],
                ["ついたち","ふつか","みっか","よっか","いつか","むいか","なのか","ようか","ここのか","とおか","じゅういちにち","じゅうににち","じゅうさんにち","じゅうよっか","じゅうごにち","じゅうろくにち"]
            ).enumerated().map { (index, pair) in (pair.0, pair.1, "\(index + 1)일") })),
            stack("날짜 · 17~31일", Array(zip(
                ["十七日","十八日","十九日","二十日","二十一日","二十二日","二十三日","二十四日","二十五日","二十六日","二十七日","二十八日","二十九日","三十日","三十一日"],
                ["じゅうしちにち","じゅうはちにち","じゅうくにち","はつか","にじゅういちにち","にじゅうににち","にじゅうさんにち","にじゅうよっか","にじゅうごにち","にじゅうろくにち","にじゅうしちにち","にじゅうはちにち","にじゅうくにち","さんじゅうにち","さんじゅういちにち"]
            ).enumerated().map { (index, pair) in (pair.0, pair.1, "\(index + 17)일") })),
            stack("사람 수 · 1~10명", [
                ("一人","ひとり","1명"), ("二人","ふたり","2명"), ("三人","さんにん","3명"),
                ("四人","よにん","4명"), ("五人","ごにん","5명"), ("六人","ろくにん","6명"),
                ("七人","ななにん","7명"), ("八人","はちにん","8명"), ("九人","きゅうにん","9명"),
                ("十人","じゅうにん","10명")
            ]),
            stack("물건 수 · 1~10개", [
                ("一つ","ひとつ","1개"), ("二つ","ふたつ","2개"), ("三つ","みっつ","3개"),
                ("四つ","よっつ","4개"), ("五つ","いつつ","5개"), ("六つ","むっつ","6개"),
                ("七つ","ななつ","7개"), ("八つ","やっつ","8개"), ("九つ","ここのつ","9개"),
                ("十","とお","10개")
            ]),
            stack("책 수 · 1~10권", counter("冊", "권", ["いっさつ","にさつ","さんさつ","よんさつ","ごさつ","ろくさつ","ななさつ","はっさつ","きゅうさつ","じゅっさつ"])),
            stack("가늘고 긴 물건 · 1~10개", counter("本", "개 · 가늘고 긴 물건", ["いっぽん","にほん","さんぼん","よんほん","ごほん","ろっぽん","ななほん","はっぽん","きゅうほん","じゅっぽん"])),
            stack("납작한 물건 · 1~10장", counter("枚", "장", ["いちまい","にまい","さんまい","よんまい","ごまい","ろくまい","ななまい","はちまい","きゅうまい","じゅうまい"])),
            stack("작은 동물 · 1~10마리", counter("匹", "마리 · 작은 동물", ["いっぴき","にひき","さんびき","よんひき","ごひき","ろっぴき","ななひき","はっぴき","きゅうひき","じゅっぴき"])),
            stack("시각 · 1~12시", [
                ("一時","いちじ","1시"), ("二時","にじ","2시"), ("三時","さんじ","3시"),
                ("四時","よじ","4시"), ("五時","ごじ","5시"), ("六時","ろくじ","6시"),
                ("七時","しちじ","7시"), ("八時","はちじ","8시"), ("九時","くじ","9시"),
                ("十時","じゅうじ","10시"), ("十一時","じゅういちじ","11시"), ("十二時","じゅうにじ","12시")
            ])
        ]
        return Library(id: libraryID, title: "묶어서 외우는 일본어", subtitle: "요일 · 월 · 날짜 · 사람 수 · 여러 가지 세는 법", stacks: stacks)
    }

    private static func stack(_ title: String, _ entries: [(String, String, String)]) -> Stack {
        let id = LibraryImporter.stableID("voca:grouped:\(title)")
        let words = entries.enumerated().map { index, entry in
            var word = Word(id: LibraryImporter.stableID("voca:grouped:\(title):\(index)"), japanese: entry.0, korean: entry.2, example: "")
            word.reading = entry.1
            return word
        }
        return Stack(id: id, title: title, words: words)
    }

    private static func counter(_ suffix: String, _ unit: String, _ readings: [String]) -> [(String, String, String)] {
        let numbers = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        return numbers.enumerated().map { index, number in (number + suffix, readings[index], "\(index + 1)\(unit)") }
    }
}
