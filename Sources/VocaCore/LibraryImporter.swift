import Foundation
import CryptoKit

public enum ImportFailure: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
public enum LibraryImporter {
    private struct Document: Decodable {
        var title: String
        var stacks: [Deck]
        struct Deck: Decodable { var title: String; var cards: [Card] }
        struct Card: Decodable { var japanese: String; var korean: String; var reading: String? }
    }
    public static func read(_ data: Data, filename: String, namespace: String? = nil) throws -> Library {
        let result: Library
        if filename.lowercased().hasSuffix(".json") {
            let doc: Document
            do { doc = try JSONDecoder().decode(Document.self, from: data) }
            catch { throw ImportFailure.invalid("JSON 형식을 확인해 주세요. title, stacks, cards와 카드의 japanese, korean이 필요합니다.") }
            result = Library(title: doc.title, stacks: doc.stacks.map { deck in
                Stack(title: deck.title, words: deck.cards.map { card in
                    var word = Word(japanese: card.japanese, korean: card.korean, example: "")
                    word.reading = card.reading
                    return word
                })
            })
        } else {
            guard let raw = String(data: data, encoding: .utf8) else { throw ImportFailure.invalid("UTF-8로 저장한 CSV 파일을 선택해 주세요.") }
            let rows = try parseCSV(raw.replacingOccurrences(of: "\u{FEFF}", with: ""))
            guard let header = rows.first else { throw ImportFailure.invalid("파일이 비어 있습니다.") }
            let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard let jp = names.firstIndex(of: "japanese"), let ko = names.firstIndex(of: "korean") else {
                throw ImportFailure.invalid("CSV 첫 행에는 japanese,korean 열이 필요합니다. stack 열은 선택 사항입니다.")
            }
            guard Set(names).count == names.count else { throw ImportFailure.invalid("CSV 헤더가 중복되어 있습니다.") }
            let stackColumn = names.firstIndex(of: "stack")
            let stackIDColumn = names.firstIndex(of: "stack_id")
            let cardIDColumn = names.firstIndex(of: "card_id")
            let readingColumn = names.firstIndex(of: "reading")
            var keys: [String] = []
            var wordKeys = Set<String>()
            var stacks: [Stack] = []
            for (index, row) in rows.dropFirst().enumerated() {
                if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
                guard row.count == header.count else { throw ImportFailure.invalid("CSV \(index + 2)행의 열 개수를 확인해 주세요.") }
                let title = stackColumn.map { row[$0] }.flatMap { $0.isEmpty ? nil : $0 } ?? "가져온 카드"
                let key = stackIDColumn.map { row[$0] } ?? title
                let wordKey = cardIDColumn.map { row[$0] } ?? "\(row[jp])|\(row[ko])"
                guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !wordKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      wordKeys.insert(key + ":" + wordKey).inserted else { throw ImportFailure.invalid("스택/카드 ID가 비어 있거나 카드 ID가 중복됩니다: \(index + 2)행") }
                var word = Word(id: namespace.map { stableID($0 + ":word:" + key + ":" + wordKey) } ?? UUID(), japanese: row[jp], korean: row[ko], example: "")
                word.reading = readingColumn.map { row[$0] }
                word.source = names.firstIndex(of: "source").map { row[$0] }
                word.license = names.firstIndex(of: "license").map { row[$0] }
                word.translationStatus = names.firstIndex(of: "translation_status").map { row[$0] }
                if let i = keys.firstIndex(of: key) { stacks[i].words.append(word) }
                else { keys.append(key); stacks.append(Stack(id: namespace.map { stableID($0 + ":stack:" + key) } ?? UUID(), title: title, words: [word])) }
            }
            result = Library(id: namespace.map { stableID($0) } ?? UUID(), title: (filename as NSString).deletingPathExtension, stacks: stacks)
        }
        guard !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !result.stacks.isEmpty,
              result.stacks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.words.isEmpty }) else {
            throw ImportFailure.invalid("라이브러리와 스택 이름, 스택마다 카드 한 개 이상이 필요합니다.")
        }
        for word in result.stacks.flatMap(\.words) {
            guard [word.japanese, word.korean].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw ImportFailure.invalid("카드의 일본어와 한국어를 채워 주세요.")
            }
        }
        guard !result.stacks.flatMap(\.words).contains(where: { $0.korean.hasPrefix("#") || $0.korean.contains("로드 중") || $0.korean.lowercased().contains("loading...") }) else {
            throw ImportFailure.invalid("한국어 번역 셀에 오류가 있습니다. 시트의 계산이 완료된 뒤 다시 가져와 주세요.")
        }
        return result
    }
    public static func stableID(_ key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
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
