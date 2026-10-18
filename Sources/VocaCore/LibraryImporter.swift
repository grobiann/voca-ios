import Foundation

public enum ImportFailure: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
public enum LibraryImporter {
    private struct Document: Decodable {
        var title: String
        var stacks: [Deck]
        struct Deck: Decodable { var title: String; var cards: [Card] }
        struct Card: Decodable { var japanese: String; var korean: String; var example: String }
    }
    public static func read(_ data: Data, filename: String) throws -> Library {
        let result: Library
        if filename.lowercased().hasSuffix(".json") {
            let doc: Document
            do { doc = try JSONDecoder().decode(Document.self, from: data) }
            catch { throw ImportFailure.invalid("JSON 형식을 확인해 주세요. title, stacks, cards와 카드의 japanese, korean, example이 필요합니다.") }
            result = Library(title: doc.title, stacks: doc.stacks.map { deck in
                Stack(title: deck.title, words: deck.cards.map { Word(japanese: $0.japanese, korean: $0.korean, example: $0.example) })
            })
        } else {
            guard let raw = String(data: data, encoding: .utf8) else { throw ImportFailure.invalid("UTF-8로 저장한 CSV 파일을 선택해 주세요.") }
            let rows = try parseCSV(raw.replacingOccurrences(of: "\u{FEFF}", with: ""))
            guard let header = rows.first else { throw ImportFailure.invalid("파일이 비어 있습니다.") }
            let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard let jp = names.firstIndex(of: "japanese"), let ko = names.firstIndex(of: "korean"), let ex = names.firstIndex(of: "example") else {
                throw ImportFailure.invalid("CSV 첫 행에는 japanese,korean,example 열이 필요합니다. stack 열은 선택 사항입니다.")
            }
            let stackColumn = names.firstIndex(of: "stack")
            var stacks: [Stack] = []
            for (index, row) in rows.dropFirst().enumerated() {
                if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
                guard row.count == header.count else { throw ImportFailure.invalid("CSV \(index + 2)행의 열 개수를 확인해 주세요.") }
                let title = stackColumn.map { row[$0] }.flatMap { $0.isEmpty ? nil : $0 } ?? "가져온 카드"
                let word = Word(japanese: row[jp], korean: row[ko], example: row[ex])
                if let i = stacks.firstIndex(where: { $0.title == title }) { stacks[i].words.append(word) }
                else { stacks.append(Stack(title: title, words: [word])) }
            }
            result = Library(title: (filename as NSString).deletingPathExtension, stacks: stacks)
        }
        guard !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !result.stacks.isEmpty,
              result.stacks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.words.isEmpty }) else {
            throw ImportFailure.invalid("라이브러리와 스택 이름, 스택마다 카드 한 개 이상이 필요합니다.")
        }
        for word in result.stacks.flatMap(\.words) {
            guard [word.japanese, word.korean, word.example].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw ImportFailure.invalid("카드의 일본어, 한국어, 예문을 모두 채워 주세요.")
            }
        }
        return result
    }
    public static func parseCSV(_ text: String) throws -> [[String]] {
        let chars = Array(text); var i = 0; var quoted = false; var closed = false
        var field = ""; var row: [String] = []; var rows: [[String]] = []
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(c) }
            } else if c == "," { row.append(field); field = ""; closed = false }
            else if c == "\n" || c == "\r\n" || c == "\r" {
                row.append(field); rows.append(row); row = []; field = ""; closed = false
            } else if c == "\"" && field.isEmpty && !closed { quoted = true }
            else {
                guard !closed && c != "\"" else { throw ImportFailure.invalid("CSV 따옴표 형식이 올바르지 않습니다.") }
                field.append(c)
            }
            i += 1
        }
        guard !quoted else { throw ImportFailure.invalid("CSV의 닫히지 않은 따옴표를 확인해 주세요.") }
        if !field.isEmpty || !row.isEmpty || closed { row.append(field); rows.append(row) }
        return rows
    }
}
