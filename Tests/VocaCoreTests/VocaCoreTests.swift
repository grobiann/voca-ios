import XCTest
@testable import VocaCore
final class VocaCoreTests: XCTestCase {
    func testLegacyMicroSettingsAndHalfHourlySchedule() throws {
        let legacy = Data(#"{"enabled":true,"intervalMinutes":60,"startHour":10,"endHour":20,"includesWeekends":true}"#.utf8)
        var settings = try JSONDecoder().decode(MicroReviewSettings.self, from: legacy)
        XCTAssertNil(settings.usesSystemAlarm)
        settings.intervalMinutes = 30
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        let dates = settings.upcomingDates(after: start, limit: 20, calendar: calendar)
        XCTAssertEqual(dates.count, 20)
        XCTAssertEqual(calendar.component(.hour, from: dates.first!), 10)
        XCTAssertEqual(calendar.component(.hour, from: dates.last!), 19)
        XCTAssertEqual(calendar.component(.minute, from: dates.last!), 30)
        for pair in zip(dates, dates.dropFirst()) { XCTAssertEqual(pair.1.timeIntervalSince(pair.0), 1800) }
    }
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
    func testRestartUsesOnlyCurrentLocalWordsAndCorrections() {
        var stack = Archive.sample.stacks[0]
        stack.prepare()
        let removedID = stack.words.removeLast().id
        stack.words[0].korean = "수정한 뜻"
        stack.prepare()
        while !stack.queue.isEmpty { stack.answer(known: true) }
        XCTAssertTrue(stack.isComplete)
        stack.reset()
        XCTAssertEqual(stack.words[0].korean, "수정한 뜻")
        XCTAssertEqual(stack.allItems.count, stack.words.count * 2)
        XCTAssertFalse(stack.allItems.contains { $0.wordID == removedID })
        XCTAssertFalse(stack.isComplete)
    }
    func testReviewDepthsAreIndependentDeduplicatedAndPersisted() throws {
        var archive = Archive.sample
        let word = archive.stacks[0].words[0]
        XCTAssertEqual(archive.configuredReviewDepthCount, 3)
        XCTAssertTrue(archive.addToReviewDepth(word, at: 1))
        XCTAssertFalse(archive.addToReviewDepth(word, at: 1))
        XCTAssertTrue(archive.addToReviewDepth(word, at: 2))
        XCTAssertFalse(archive.addToReviewDepth(word, at: 4))
        archive.reviewDepthStacks![0].words.removeAll()
        archive.reviewDepthStacks![0].prepare()
        XCTAssertEqual(archive.stacks[0].words.count, 4)
        XCTAssertEqual(archive.reviewDepthStacks![1].words, [word])
        archive.reviewDepthCount = 5
        XCTAssertTrue(archive.addToReviewDepth(word, at: 5))
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.reviewDepthStacks![1].words, [word])
        XCTAssertEqual(restored.reviewDepthStacks![4].words, [word])
        XCTAssertEqual(restored.configuredReviewDepthCount, 5)
    }
    func testMovingReviewWordRemovesOnlyPreviousDepthAndPrunesQueue() {
        var archive = Archive.sample
        let word = archive.stacks[0].words[0]
        XCTAssertTrue(archive.addToReviewDepth(word, at: 1))
        XCTAssertTrue(archive.moveToReviewDepth(word, from: 1))
        XCTAssertTrue(archive.reviewDepthStacks![0].words.isEmpty)
        XCTAssertTrue(archive.reviewDepthStacks![0].queue.isEmpty)
        XCTAssertEqual(archive.reviewDepthStacks![1].words, [word])
        XCTAssertEqual(archive.stacks[0].words[0], word)
        XCTAssertFalse(archive.moveToReviewDepth(word, from: 1))
        XCTAssertTrue(archive.moveToReviewDepth(word, from: 2))
        XCTAssertTrue(archive.reviewDepthStacks![1].words.isEmpty)
        XCTAssertEqual(archive.reviewDepthStacks![2].words, [word])
        XCTAssertFalse(archive.moveToReviewDepth(word, from: 3))
    }
    func testDepthCorrectionAndLegacyCardCountSetting() throws {
        var archive = Archive.sample
        let stack = archive.stacks[0]
        let word = stack.words[0]
        XCTAssertTrue(archive.addToReviewDepth(word, at: 1))
        archive.recordMeaningCorrection(library: nil, stack: stack, word: word, correctedKorean: "수정된 뜻")
        XCTAssertEqual(archive.reviewDepthStacks![0].words[0].korean, "수정된 뜻")
        let old = try JSONDecoder().decode(Archive.self, from: Data("{\"stacks\":[],\"libraries\":[],\"server\":[]}".utf8))
        XCTAssertNil(old.microSessionCardCount)
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
        let csv = "\u{FEFF}stack,japanese,korean,example\r\n인사,こんにちは,안녕하세요,\"こんにちは、田中さん。\"\r\n카페,注文,\"주문, \"\"부탁해요\"\"\n감사합니다\",\"一つ、お願いします。\"\r\n"
        let library = try LibraryImporter.read(Data(csv.utf8), filename: "생활.csv")
        XCTAssertEqual(library.stacks.count, 2); XCTAssertEqual(library.wordCount, 2)
        XCTAssertTrue(library.stacks[1].words[0].korean.contains("\"부탁해요\""))
        XCTAssertTrue(library.stacks[1].words[0].korean.contains("\n"))
        XCTAssertTrue(library.stacks.flatMap(\.words).allSatisfy { $0.example.isEmpty })
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
        XCTAssertEqual(library.stacks[0].words[0].example, "")
        let minimal = #"{"title":"기본","stacks":[{"title":"요일","cards":[{"japanese":"月曜日","korean":"월요일","reading":"げつようび"}]}]}"#
        XCTAssertEqual(try LibraryImporter.read(Data(minimal.utf8), filename: "minimal.json").stacks[0].words[0].reading, "げつようび")
    }
    func testGroupedExpressionsAndExampleMigration() {
        let library = GroupedExpressions.library
        XCTAssertEqual(library.stacks.count, 11)
        XCTAssertEqual(library.wordCount, 122)
        XCTAssertTrue(library.stacks.allSatisfy { !$0.words.isEmpty && $0.words.count <= 20 })
        XCTAssertTrue(library.stacks.flatMap(\.words).allSatisfy { $0.example.isEmpty && !($0.reading ?? "").isEmpty })
        XCTAssertEqual(library.stacks[2].words[0].reading, "ついたち")
        XCTAssertEqual(library.stacks[4].words[0].reading, "ひとり")
        var archive = Archive.sample
        archive.stacks[0].words[0].example = "옛 예문"
        archive.libraries = [library]
        archive.libraries[0].stacks[0].words[0].example = "옛 예문"
        XCTAssertTrue(archive.removeLegacyExamples())
        XCTAssertTrue(archive.stacks[0].words[0].example.isEmpty)
        XCTAssertTrue(archive.libraries[0].stacks[0].words[0].example.isEmpty)
        XCTAssertFalse(archive.removeLegacyExamples())
    }
    func testGroupedSheetKeepsBuiltInStackAndCardIDs() throws {
        let original = GroupedExpressions.library.stacks[0]
        let card = original.words[0]
        let csv = "stack_id,stack,card_id,japanese,reading,korean\n\(original.id),\(original.title),\(card.id),\(card.japanese),\(card.reading!),\(card.korean)\n"
        let imported = try LibraryImporter.read(Data(csv.utf8), filename: "묶어서 외우는 일본어.csv", namespace: "sheet-link")
        XCTAssertEqual(imported.stacks[0].id, original.id)
        XCTAssertEqual(imported.stacks[0].words[0].id, card.id)
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
        XCTAssertNil(old.studyPoolSize); XCTAssertNil(old.wordReports); XCTAssertNil(old.showReadingOnFront)
        var archive = Archive.sample
        archive.studyPoolSize = 30
        archive.showReadingOnFront = false
        let restoredReadingSetting = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restoredReadingSetting.showReadingOnFront, false)
        let report = WordReport(library: archive.server.first, stack: archive.stacks[0], word: archive.stacks[0].words[0], message: "뜻 확인")
        archive.wordReports = [report]
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.studyPoolSize, 30); XCTAssertEqual(restored.wordReports, [report])
        XCTAssertTrue(report.shareText.contains("뜻 확인"))
    }
    func testMeaningCorrectionKeepsOriginalReportAndUpdatesMyCard() throws {
        var archive = Archive.sample
        let originalStack = archive.stacks[0]
        let originalWord = originalStack.words[0]
        archive.microReviewEntries = [MicroReviewEntry(word: originalWord, sourceTitle: originalStack.title)]
        let updated = archive.recordMeaningCorrection(library: archive.server[0], stack: originalStack,
                                                     word: originalWord, correctedKorean: "  안녕한 아침  ")
        XCTAssertTrue(updated)
        XCTAssertEqual(archive.stacks[0].words[0].korean, "안녕한 아침")
        XCTAssertEqual(archive.microReviewEntries?[0].word.korean, "안녕한 아침")
        XCTAssertEqual(archive.server[0].stacks[0].words[0].korean, originalWord.korean)
        XCTAssertEqual(archive.wordReports?[0].word.korean, originalWord.korean)
        XCTAssertEqual(archive.wordReports?[0].correctedKorean, "안녕한 아침")
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.stacks[0].words[0].korean, "안녕한 아침")
        XCTAssertEqual(restored.wordReports?[0].correctedKorean, "안녕한 아침")
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
            XCTAssertTrue(library.stacks.flatMap(\.words).allSatisfy { $0.example.isEmpty && !($0.reading ?? "").isEmpty && $0.source != nil })
        }
    }
}
