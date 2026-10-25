import Foundation

public struct Word: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var japanese: String
    public var korean: String
    public var example: String
    public var reading: String?
    public var source: String?
    public var license: String?
    public var exampleSource: String?
    public var translationStatus: String?
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
    public var recentWordIDs: [UUID]?
    public var hasShuffledQueue: Bool?
    public static let poolLimit = 20
    public var remainingCount: Int { allItems.filter { !mastered.contains($0) }.count }
    public init(id: UUID = UUID(), title: String, words: [Word] = [], sourceID: UUID? = nil) {
        self.id = id; self.title = title; self.words = words; self.mastered = []; self.queue = []; self.sourceID = sourceID
    }
    public var allItems: [ReviewItem] {
        Direction.allCases.flatMap { direction in words.map { ReviewItem(wordID: $0.id, direction: direction) } }
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
}
public struct Archive: Codable, Sendable {
    public var studyPoolSize: Int?
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
        for stackIndex in stacks.indices where stacks[stackIndex].id == stack.id || stacks[stackIndex].sourceID == stack.id {
            guard let wordIndex = stacks[stackIndex].words.firstIndex(where: { $0.id == word.id }) else { continue }
            stacks[stackIndex].words[wordIndex].korean = correction
            updatedMyCard = true
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

public struct MicroReviewSettings: Codable, Equatable, Sendable {
    public var usesSystemAlarm: Bool?
    public var enabled = false
    public var intervalMinutes = 60
    public var startHour = 10
    public var endHour = 20
    public var includesWeekends = true
    public init() {}

    public func upcomingDates(after date: Date, limit: Int = 60, calendar: Calendar = .current) -> [Date] {
        guard limit > 0, intervalMinutes > 0, startHour >= 0, endHour <= 24, startHour < endHour else { return [] }
        var dates: [Date] = []
        let startOfToday = calendar.startOfDay(for: date)
        for dayOffset in 0..<30 where dates.count < limit {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if !includesWeekends && (weekday == 1 || weekday == 7) { continue }
            for minutes in stride(from: startHour * 60, to: endHour * 60, by: intervalMinutes) where dates.count < limit {
                guard let slot = calendar.date(byAdding: .minute, value: minutes, to: day), slot > date else { continue }
                dates.append(slot)
            }
        }
        return dates
    }
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
    public mutating func answer(known: Bool, at date: Date = Date()) {
        guard status == .active else { return }
        lastReviewedAt = date
        if known {
            successCount = min(3, successCount + 1)
            if successCount == 3 { status = .completed }
        }
    }
    public mutating func stop() { if status == .active { status = .stopped } }
    public mutating func restart() {
        successCount = 0; lastReviewedAt = nil; status = .active
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
        "틀린 단어 제보\n라이브러리: \(libraryTitle ?? "내 스택")\n스택: \(stackTitle)\n일본어: \(word.japanese)\n읽기: \(word.reading ?? "")\n기존 한국어 뜻: \(word.korean)\n\(correctedKorean.map { "올바른 한국어 뜻: \($0)" } ?? "제보 내용: \(message)")\n단어 ID: \(word.id)\n스택 ID: \(stackID)\n출처: \(word.source ?? "직접 등록")"
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
