import XCTest
@testable import VocaCore
final class VocaCoreTests: XCTestCase {
    func testBothDirectionsAndRetry() {
        var stack = Archive.sample.stacks[0]; stack.prepare()
        XCTAssertEqual(stack.queue.count, stack.words.count)
        let first = stack.queue[0]; stack.answer(known: false)
        XCTAssertEqual(stack.queue[3], first)
        XCTAssertEqual(stack.mastered.count, 0)
        for _ in 0..<stack.words.count { stack.answer(known: true) }
        XCTAssertFalse(stack.isComplete)
        while !stack.queue.isEmpty { stack.answer(known: true) }
        XCTAssertTrue(stack.isComplete); XCTAssertEqual(stack.progress, 1)
        stack.reset(); XCTAssertFalse(stack.isComplete); XCTAssertEqual(stack.mastered.count, 0)
    }
    func testResumeAndRemoval() throws {
        var stack = Archive.sample.stacks[0]; stack.prepare(); stack.answer(known: true); stack.answer(known: false)
        let saved = try JSONEncoder().encode(stack)
        var restored = try JSONDecoder().decode(Stack.self, from: saved)
        restored.prepare(); XCTAssertEqual(restored, stack)
        restored.words.removeAll(); restored.prepare()
        XCTAssertTrue(restored.queue.isEmpty); XCTAssertTrue(restored.mastered.isEmpty); XCTAssertFalse(restored.isComplete)
    }
    func testCSVQuotesNewlinesAndGroups() throws {
        let csv = "\u{FEFF}stack,japanese,korean,example\r\n인사,こんにちは,안녕하세요,\"こんにちは、田中さん。\"\r\n카페,注文,주문,\"一つ、\"\"お願いします\"\"。\nありがとう。\"\r\n"
        let library = try LibraryImporter.read(Data(csv.utf8), filename: "생활.csv")
        XCTAssertEqual(library.stacks.count, 2); XCTAssertEqual(library.wordCount, 2)
        XCTAssertTrue(library.stacks[1].words[0].example.contains("\"お願いします\""))
        XCTAssertTrue(library.stacks[1].words[0].example.contains("\n"))
    }
    func testInvalidImports() {
        for csv in ["japanese,korean,example\na,b", "japanese,korean,example\n\"a,b,c", "bad,header\na,b"] {
            XCTAssertThrowsError(try LibraryImporter.read(Data(csv.utf8), filename: "test.csv"))
        }
        XCTAssertThrowsError(try LibraryImporter.read(Data("{\"title\":\"x\",\"stacks\":[]}".utf8), filename: "test.json"))
    }
    func testJSON() throws {
        let json = """
        {"title":"여행","stacks":[{"title":"인사","cards":[{"japanese":"こんにちは","korean":"안녕하세요","example":"こんにちは、田中さん。"}]}]}
        """
        let library = try LibraryImporter.read(Data(json.utf8), filename: "test.json")
        XCTAssertEqual(library.wordCount, 1); XCTAssertEqual(library.title, "여행")
    }
    func testPoolLimitAndWrongAnswersDoNotAdmitWords() {
        var stack = Stack(title: "100 words", words: (0..<100).map { Word(japanese: "語\($0)", korean: "말\($0)", example: "例") })
        stack.prepare()
        let initial = Set(stack.queue.map(\.wordID))
        for _ in 0..<120 { stack.answer(known: false); XCTAssertEqual(Set(stack.queue.map(\.wordID)), initial) }
        XCTAssertEqual(stack.queue.count, 10)
        let answered = stack.queue[0].wordID
        stack.answer(known: true)
        XCTAssertEqual(stack.queue.count, 10)
        XCTAssertFalse(stack.queue.contains { $0.wordID == answered })
        XCTAssertNotEqual(Set(stack.queue.map(\.wordID)), initial)
        while !stack.queue.isEmpty {
            XCTAssertLessThanOrEqual(stack.queue.count, 10)
            XCTAssertEqual(Set(stack.queue.map(\.wordID)).count, stack.queue.count)
            stack.answer(known: true)
        }
        XCTAssertTrue(stack.isComplete)
    }
    func testSmallPoolSeparatesReverseAndLegacyQueueMigrates() throws {
        var stack = Archive.sample.stacks[0]
        stack.queue = stack.allItems // saved by version 1
        stack.prepare()
        XCTAssertEqual(stack.queue.count, 4)
        let first = stack.queue[0]
        stack.answer(known: true)
        XCTAssertFalse(stack.queue.contains { $0.wordID == first.wordID })
        for _ in 0..<3 { stack.answer(known: true) }
        XCTAssertTrue(stack.queue.allSatisfy { $0.direction == .koreanToJapanese })
        let saved = try JSONEncoder().encode(stack)
        var restored = try JSONDecoder().decode(Stack.self, from: saved)
        restored.prepare(); XCTAssertEqual(restored, stack)
    }
    func testStableSheetIDsAndStackGrouping() throws {
        let csv = "stack_id,stack,card_id,japanese,korean,example\na,같은 이름,1,猫,고양이,\nb,같은 이름,2,犬,개,"
        let a = try LibraryImporter.read(Data(csv.utf8), filename: "N5.csv", namespace: "sheet:N5")
        let b = try LibraryImporter.read(Data(csv.utf8), filename: "N5.csv", namespace: "sheet:N5")
        XCTAssertEqual(a, b); XCTAssertEqual(a.stacks.count, 2)
        XCTAssertNotEqual(a.stacks[0].id, a.stacks[1].id)
        let c = try LibraryImporter.read(Data(csv.utf8), filename: "N4.csv", namespace: "sheet:N4")
        XCTAssertNotEqual(a.id, c.id)
        let url = try SheetURL.csvURL(from: "https://docs.google.com/spreadsheets/d/abc/edit#gid=123", sheetName: "N5")
        XCTAssertTrue(url.absoluteString.contains("sheet=N5"))
        XCTAssertFalse(url.absoluteString.contains("gid=123"))
    }
    func testSheetURLs() throws {
        let url = try SheetURL.csvURL(from: "https://docs.google.com/spreadsheets/d/abc/edit#gid=42")
        XCTAssertEqual(url.absoluteString, "https://docs.google.com/spreadsheets/d/abc/export?format=csv&gid=42")
        XCTAssertTrue(try SheetURL.csvURL(from: "https://docs.google.com/spreadsheets/d/e/abc/pubhtml?gid=7").absoluteString.contains("/d/e/abc/pub?output=csv&gid=7"))
        XCTAssertThrowsError(try SheetURL.csvURL(from: "https://example.com/spreadsheets/d/abc/edit"))
    }
}

extension VocaCoreTests {
    func testPublicTabManifestAndEscapedNames() throws {
        let html = #"items.push({name: "N5", pageUrl: "https:\/\/example.com?headers\x3dtrue", gid: "123",initialSheet: false});items.push({name: "여행 \x26 \"일상\"", pageUrl: "x", gid: "456",initialSheet: false});"#
        let tabs = try SheetURL.tabs(from: Data(html.utf8))
        XCTAssertEqual(tabs.map(\.name), ["N5", "여행 & \"일상\""])
        XCTAssertEqual(tabs.map(\.id), ["123", "456"])
        XCTAssertEqual(try SheetURL.csvURL(from: "https://docs.google.com/spreadsheets/d/abc/edit", tab: tabs[1]).absoluteString,
                       "https://docs.google.com/spreadsheets/d/abc/export?format=csv&gid=456")
        XCTAssertThrowsError(try SheetURL.tabs(from: Data("<html>Sign in</html>".utf8)))
    }
    func testDownloadedWorkbook() throws {
        let defaultRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Data/JLPT")
        let root = ProcessInfo.processInfo.environment["VOCA_SHEET_FIXTURES"].map { URL(fileURLWithPath: $0) } ?? defaultRoot
        let manifest = root.appendingPathComponent("htmlview.html")
        if FileManager.default.fileExists(atPath: manifest.path) {
            let tabs = try SheetURL.tabs(from: Data(contentsOf: manifest))
            XCTAssertEqual(tabs.map(\.name), ["N5", "N4", "N3", "N2", "N1"])
        }
        for (name, count, stacks) in [("N5",674,34),("N4",630,32),("N3",1659,83),("N2",1778,89),("N1",3070,154)] {
            let library = try LibraryImporter.read(Data(contentsOf: root.appendingPathComponent(name + ".csv")), filename: name + ".csv", namespace: name)
            XCTAssertEqual(library.wordCount, count)
            XCTAssertEqual(library.stacks.count, stacks)
            XCTAssertTrue(library.stacks.allSatisfy { $0.words.count <= 20 })
            XCTAssertTrue(library.stacks.flatMap(\.words).allSatisfy { !$0.example.isEmpty && !($0.reading ?? "").isEmpty && $0.source != nil })
        }
    }
}
