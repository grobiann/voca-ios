import XCTest
@testable import VocaCore
final class VocaCoreTests: XCTestCase {
    func testBothDirectionsAndRetry() {
        var stack = Archive.sample.stacks[0]; stack.prepare()
        XCTAssertEqual(stack.queue.count, stack.words.count * 2)
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
        for csv in ["japanese,korean,example\na,b", "japanese,korean,example\na,b,", "japanese,korean,example\n\"a,b,c", "bad,header\na,b"] {
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
    func testSheetURLs() throws {
        let url = try SheetURL.csvURL(from: "https://docs.google.com/spreadsheets/d/abc/edit#gid=42")
        XCTAssertEqual(url.absoluteString, "https://docs.google.com/spreadsheets/d/abc/export?format=csv&gid=42")
        XCTAssertTrue(try SheetURL.csvURL(from: "https://docs.google.com/spreadsheets/d/e/abc/pubhtml?gid=7").absoluteString.contains("/d/e/abc/pub?output=csv&gid=7"))
        XCTAssertThrowsError(try SheetURL.csvURL(from: "https://example.com/spreadsheets/d/abc/edit"))
    }
}
