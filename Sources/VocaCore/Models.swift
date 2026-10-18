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
    public static let poolLimit = 10
    public var remainingCount: Int { allItems.filter { !mastered.contains($0) }.count }
    public init(id: UUID = UUID(), title: String, words: [Word] = [], sourceID: UUID? = nil) {
        self.id = id; self.title = title; self.words = words; self.mastered = []; self.queue = []; self.sourceID = sourceID
    }
    public var allItems: [ReviewItem] {
        Direction.allCases.flatMap { direction in words.map { ReviewItem(wordID: $0.id, direction: direction) } }
    }
    public var isComplete: Bool { !words.isEmpty && allItems.allSatisfy { mastered.contains($0) } }
    public var progress: Double { allItems.isEmpty ? 0 : Double(allItems.filter { mastered.contains($0) }.count) / Double(allItems.count) }
    public mutating func prepare() {
        let valid = Set(allItems)
        mastered.formIntersection(valid)
        var seenWords = Set<UUID>()
        queue = Array(queue.filter {
            valid.contains($0) && !mastered.contains($0) && seenWords.insert($0.wordID).inserted
        }.prefix(Self.poolLimit))
        refill()
    }
    private mutating func refill() {
        let activeWords = Set(queue.map(\.wordID))
        let recent = recentWordIDs ?? []
        var pending = allItems.filter { !mastered.contains($0) && !activeWords.contains($0.wordID) }
        // Avoid admitting the reverse direction immediately after answering its partner.
        let cooled = pending.filter { !recent.contains($0.wordID) }
        if !cooled.isEmpty { pending = cooled }
        else if !queue.isEmpty { return }
        else {
            pending.sort { (recent.firstIndex(of: $0.wordID) ?? -1) < (recent.firstIndex(of: $1.wordID) ?? -1) }
        }
        var admitted = activeWords
        for item in pending where queue.count < Self.poolLimit {
            if admitted.insert(item.wordID).inserted { queue.append(item) }
        }
    }
    public mutating func answer(known: Bool) {
        guard !queue.isEmpty else { return }
        let current = queue.removeFirst()
        if known {
            mastered.insert(current)
            var recent = (recentWordIDs ?? []).filter { $0 != current.wordID }
            recent.append(current.wordID)
            recentWordIDs = Array(recent.suffix(Self.poolLimit))
            refill()
        } else {
            // Retry only within the current pool; an incorrect answer never admits a new word.
            queue.insert(current, at: min(3, queue.count))
        }
    }
    public mutating func reset() { mastered = []; queue = []; recentWordIDs = []; prepare() }

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
    public var stacks: [Stack]
    public var libraries: [Library]
    public var server: [Library]
    public init(stacks: [Stack] = [], libraries: [Library] = [], server: [Library] = []) {
        self.stacks = stacks; self.libraries = libraries; self.server = server
    }
    public static var sample: Archive {
        let daily = Stack(title: "하루를 시작하는 말", words: [
            Word(japanese: "おはようございます", korean: "좋은 아침이에요", example: "先生、おはようございます。"),
            Word(japanese: "楽しみ", korean: "기대, 즐거움", example: "明日の旅行が楽しみです。"),
            Word(japanese: "散歩", korean: "산책", example: "毎朝、公園を散歩します。"),
            Word(japanese: "ゆっくり", korean: "천천히, 느긋하게", example: "今日はゆっくり休みます。")])
        let travel = Stack(title: "카페에서", words: [
            Word(japanese: "おすすめ", korean: "추천", example: "おすすめの飲み物は何ですか。"),
            Word(japanese: "持ち帰り", korean: "포장, 테이크아웃", example: "持ち帰りでお願いします。")])
        return Archive(stacks: [daily], server: [Library(title: "작은 일본어 생활", subtitle: "매일 만나는 표현부터, 가볍게", stacks: [daily, travel])])
    }
}
