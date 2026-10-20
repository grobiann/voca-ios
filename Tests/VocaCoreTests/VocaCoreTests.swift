import XCTest
@testable import VocaCore
final class VocaCoreTests: XCTestCase {
    func testBothDirectionsAndRetry() {
        var stack = Archive.sample.stacks[0]; stack.prepare()
        XCTAssertEqual(stack.queue.count, stack.words.count)
        let first = stack.queue[0]; stack.answer(known: false)
        XCTAssertTrue(stack.queue.dropFirst(3).contains(first))
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
    func testDeletingMasteredWordPrunesItsReviewState() {
        var stack = Archive.sample.stacks[0]
        stack.prepare()
        let reviewed = stack.queue[0].wordID
        stack.answer(known: true)
        XCTAssertEqual(stack.mastered.count, 1)
        stack.words.removeAll { $0.id == reviewed }
        stack.prepare()
        XCTAssertEqual(stack.mastered.count, 0)
        XCTAssertFalse(stack.queue.contains { $0.wordID == reviewed })
        XCTAssertEqual(stack.allItems.count, 6)
    }
    func testMicroReviewThreeSuccessesAndStop() throws {
        let word = Archive.sample.stacks[0].words[0]
        var entry = MicroReviewEntry(word: word, sourceTitle: "인사")
        entry.answer(known: true)
        entry.answer(known: false)
        XCTAssertEqual(entry.successCount, 1)
        entry.answer(known: true)
        XCTAssertEqual(entry.status, .active)
        entry.answer(known: true)
        XCTAssertEqual(entry.successCount, 3)
        XCTAssertEqual(entry.status, .completed)
        entry.answer(known: true)
        XCTAssertEqual(entry.successCount, 3)
        entry.restart()
        XCTAssertEqual(entry.successCount, 0)
        entry.stop()
        XCTAssertEqual(entry.status, .stopped)
        let restored = try JSONDecoder().decode(MicroReviewEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(restored, entry)
        let oldArchive = try JSONDecoder().decode(Archive.self, from: Data("{\"stacks\":[],\"libraries\":[],\"server\":[]}".utf8))
        XCTAssertNil(oldArchive.microReviewSettings)
        XCTAssertNil(oldArchive.microReviewEntries)
    }
    func testMicroReviewScheduleHonorsHoursAndWeekdaysWithoutDailyCap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 9))!
        let settings = MicroReviewSettings()
        let slots = settings.upcomingDates(after: monday, limit: 60, calendar: calendar)
        XCTAssertEqual(slots.count, 60)
        XCTAssertEqual(calendar.component(.hour, from: slots[0]), 10)
        XCTAssertEqual(calendar.component(.hour, from: slots[9]), 19)
        XCTAssertTrue(slots.allSatisfy { (10..<20).contains(calendar.component(.hour, from: $0)) })
        XCTAssertTrue(slots.contains { [1, 7].contains(calendar.component(.weekday, from: $0)) })
        var weekdays = settings; weekdays.includesWeekends = false
        XCTAssertTrue(weekdays.upcomingDates(after: monday, calendar: calendar).allSatisfy { ![1, 7].contains(calendar.component(.weekday, from: $0)) })
        var faster = settings; faster.intervalMinutes = 30
        let fastSlots = faster.upcomingDates(after: monday, limit: 60, calendar: calendar)
        XCTAssertEqual(calendar.component(.minute, from: fastSlots[1]), 30)
        XCTAssertEqual(fastSlots.count, 60)
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
        XCTAssertEqual(stack.queue.count, 20)
        let answered = stack.queue[0].wordID
        stack.answer(known: true)
        XCTAssertEqual(stack.queue.count, 20)
        XCTAssertFalse(stack.queue.contains { $0.wordID == answered })
        XCTAssertNotEqual(Set(stack.queue.map(\.wordID)), initial)
        while !stack.queue.isEmpty {
            XCTAssertLessThanOrEqual(stack.queue.count, 20)
            XCTAssertEqual(Set(stack.queue.map(\.wordID)).count, stack.queue.count)
            stack.answer(known: true)
        }
        XCTAssertTrue(stack.isComplete)
    }
    func testTwentyWordPoolStaysFullAndAnswersAreMixed() {
        var stack = Stack(title: "Twenty", words: (0..<20).map { Word(japanese: "語\($0)", korean: "말\($0)", example: "例") })
        stack.prepare()
        XCTAssertEqual(stack.queue.count, 20)
        XCTAssertEqual(Set(stack.queue.map(\.wordID)).count, 20)
        for _ in 0..<30 {
            let current = stack.queue[0]
            stack.answer(known: true)
            XCTAssertFalse(stack.queue.prefix(2).contains { $0.wordID == current.wordID })
            XCTAssertEqual(Set(stack.queue.map(\.wordID)).count, stack.queue.count)
            let distinctPending = Set(stack.allItems.filter { !stack.mastered.contains($0) }.map(\.wordID)).count
            XCTAssertEqual(stack.queue.count, min(20, distinctPending))
        }
        let before = Set(stack.queue)
        let wrong = stack.queue[0]
        stack.answer(known: false)
        XCTAssertEqual(Set(stack.queue), before)
        XCTAssertFalse(stack.queue.prefix(2).contains(wrong))
    }
    func testSmallPoolSeparatesReverseAndLegacyQueueMigrates() throws {
        var stack = Archive.sample.stacks[0]
        stack.queue = stack.allItems // saved by version 1
        stack.prepare()
        XCTAssertEqual(stack.queue.count, 4)
        let first = stack.queue[0]
        stack.answer(known: true)
        XCTAssertFalse(stack.queue.prefix(2).contains { $0.wordID == first.wordID })
        for _ in 0..<3 { stack.answer(known: true) }
        XCTAssertTrue(stack.queue.allSatisfy { $0.direction == .koreanToJapanese })
        let saved = try JSONEncoder().encode(stack)
        var restored = try JSONDecoder().decode(Stack.self, from: saved)
        restored.prepare(); XCTAssertEqual(restored, stack)
    }
    func testConfigurablePoolAndArchiveCompatibility() throws {
        var stack = Stack(title: "Pool", words: (0..<60).map { Word(japanese: "語\($0)", korean: "말", example: "") })
        stack.prepare(); XCTAssertEqual(stack.queue.count, 20)
        stack.answer(known: true)
        let mastered = stack.mastered
        stack.prepare(poolSize: 5); XCTAssertEqual(stack.queue.count, 5)
        stack.prepare(poolSize: 30); XCTAssertEqual(stack.queue.count, 30)
        XCTAssertEqual(stack.mastered, mastered)
        let initial = Set(stack.queue)
        stack.answer(known: false, poolSize: 30); XCTAssertEqual(Set(stack.queue), initial)
        stack.prepare(poolSize: 1)
        var answers = 0
        while !stack.queue.isEmpty && answers < 120 { stack.answer(known: true, poolSize: 1); answers += 1 }
        XCTAssertTrue(stack.isComplete)
        let old = try JSONDecoder().decode(Archive.self, from: Data("{\"stacks\":[],\"libraries\":[],\"server\":[]}".utf8))
        XCTAssertNil(old.studyPoolSize); XCTAssertNil(old.wordReports)
        var archive = Archive.sample
        archive.studyPoolSize = 30
        let report = WordReport(library: archive.server.first, stack: archive.stacks[0], word: archive.stacks[0].words[0], message: "뜻 확인")
        archive.wordReports = [report]
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.studyPoolSize, 30); XCTAssertEqual(restored.wordReports, [report])
        XCTAssertTrue(report.shareText.contains("뜻 확인"))
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
