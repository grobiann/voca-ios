import XCTest
@testable import VocaCore
final class VocaCoreTests: XCTestCase {
    func testOneWayAndSentenceCards() throws {
        var stack = Stack(title: "단어", words: [Word(japanese: "猫", korean: "고양이", example: "")])
        stack.oneWay = true
        stack.prepare()
        XCTAssertEqual(stack.allItems.count, 1)
        stack.answer(known: true)
        XCTAssertTrue(stack.isComplete)

        let csv = "stack,card_id,ja-JP,reading,ko-KR,type\n인사,hello_1,こんにちは。,-,안녕하세요.,sentence\n"
        let deck = try LibraryImporter.read(Data(csv.utf8), filename: "문장.csv", namespace: "test")
        var sentence = deck.stacks[0]
        sentence.prepare()
        XCTAssertTrue(sentence.words[0].isSentence == true)
        XCTAssertEqual(sentence.allItems.map(\.direction), [.japaneseToKorean])
        let mixed = csv + "인사,hello_2,ありがとう,-,고마워요,word\n"
        XCTAssertThrowsError(try LibraryImporter.read(Data(mixed.utf8), filename: "혼합.csv", namespace: "test"))
    }
    func testReviewWaitUsesSharedClockBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10, minute: 1))!
        let second = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10, minute: 29))!
        XCTAssertEqual(Archive.nextReviewBoundary(after: first, minutes: 30, calendar: calendar),
                       Archive.nextReviewBoundary(after: second, minutes: 30, calendar: calendar))
        let dayA = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10))!
        let boundary = Archive.nextReviewBoundary(after: dayA, minutes: 2880, calendar: calendar)
        let preceding = calendar.date(byAdding: .day, value: -1, to: boundary)!
        let earlier = calendar.date(byAdding: .day, value: -2, to: boundary)!
        XCTAssertEqual(Archive.nextReviewBoundary(after: preceding, minutes: 2880, calendar: calendar), boundary)
        XCTAssertEqual(Archive.nextReviewBoundary(after: earlier, minutes: 2880, calendar: calendar), boundary)
    }
    func testReviewSessionExcludesWaitingCard() {
        var archive = Archive()
        let word = Word(japanese: "水", korean: "물", example: "")
        archive.reviewDepthCount = 3
        XCTAssertTrue(archive.addToReviewDepth(word, at: 1))
        archive.reviewReadyAt = [word.id: Date(timeIntervalSince1970: 2_000)]
        XCTAssertTrue(archive.reviewSession(now: Date(timeIntervalSince1970: 1_000)).words.isEmpty)
        XCTAssertEqual(archive.reviewSession(now: Date(timeIntervalSince1970: 3_000)).words.count, 1)
    }
    func testLegacyReminderSaveRemainsReadableWithoutReminderBehavior() throws {
        var original = Archive.sample
        original.stacks[0].prepare()
        original.stacks[0].answer(known: true)
        original.microReviewEntries = [MicroReviewEntry(word: original.stacks[0].words[0], sourceTitle: "이전 알림 풀")]
        original.microReviewSettings = MicroReviewSettings()
        original.microReviewSettings?.enabled = true
        original.microReviewSettings?.usesSystemAlarm = true
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.stacks[0].mastered, original.stacks[0].mastered)
        XCTAssertEqual(restored.microReviewEntries, original.microReviewEntries)
        XCTAssertEqual(restored.libraries, original.libraries)
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
    func testReviewWordHasExactlyOneDepthAcrossPersistence() throws {
        var archive = Archive.sample
        let word = archive.stacks[0].words[0]
        XCTAssertTrue(archive.addToReviewDepth(word, at: 1))
        XCTAssertFalse(archive.addToReviewDepth(word, at: 2))
        XCTAssertTrue(archive.advanceReviewDepthWord(word, from: 1))
        archive.reviewDepthCount = 10
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.reviewDepth(of: word.id), 2)
        XCTAssertEqual(restored.reviewDepthStacks!.flatMap(\.words).filter { $0.id == word.id }.count, 1)
        XCTAssertEqual(restored.configuredReviewDepthCount, 10)
    }
    func testMixedDepthFlowDoesNotRepeatPromotedWords() {
        var archive = Archive.sample
        let words = archive.stacks[0].words
        for (index, word) in words.enumerated() { _ = archive.addToReviewDepth(word, at: index % 3 + 1) }
        var session = archive.reviewSession(poolSize: 2)
        XCTAssertEqual(Set(session.words.map(\.id)), Set(words.map(\.id)))
        let original = Set(session.words.map(\.id))
        session.answerReviewSession(known: false, poolSize: 2)
        XCTAssertEqual(Set(session.words.map(\.id)), original)
        var answered = Set<UUID>()
        while let item = session.queue.first {
            XCTAssertTrue(answered.insert(item.wordID).inserted)
            let word = session.words.first { $0.id == item.wordID }!
            _ = archive.advanceReviewDepthWord(word, from: archive.reviewDepth(of: word.id)!)
            session.answerReviewSession(known: true, poolSize: 2)
        }
        XCTAssertEqual(answered, original)
        XCTAssertTrue(session.words.isEmpty)
        XCTAssertTrue(archive.reviewSession().words.isEmpty)
        let nextDay = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        XCTAssertFalse(archive.reviewSession(now: nextDay).words.isEmpty)
    }
    func testLegacyDuplicateMigrationAndTwentyStages() {
        var archive = Archive.sample
        let word = archive.stacks[0].words[0]
        archive.prepareReviewDepths()
        archive.reviewDepthStacks![0].words = [word]
        archive.reviewDepthStacks![2].words = [word]
        archive.prepareReviewDepths()
        XCTAssertEqual(archive.reviewDepth(of: word.id), 3)
        XCTAssertTrue(archive.reviewDepthStacks![0].words.isEmpty)
        archive.reviewDepthCount = 20
        for depth in 3...20 { XCTAssertTrue(archive.advanceReviewDepthWord(word, from: depth)) }
        XCTAssertNil(archive.reviewDepth(of: word.id))
        XCTAssertEqual(archive.completedReviewWords, [word])
        XCTAssertTrue(archive.reviewSession().words.isEmpty)
        XCTAssertEqual(archive.configuredReviewDepthCount, 20)
    }
    func testKanaNormalization() {
        var word = Word(japanese: "カメラ", korean: "카메라", example: "")
        for reading in [nil, "", "  ", " - ", "—", "－"] as [String?] {
            word.reading = reading
            XCTAssertNil(word.normalizedReading)
            XCTAssertEqual(word.kanaText, "カメラ")
        }
        word.japanese = "時間"; word.reading = " じかん "
        XCTAssertEqual(word.kanaText, "じかん")
    }
    func testMovingReviewWordRemovesOnlyPreviousDepthAndPrunesQueue() {
        var archive = Archive.sample
        archive.reviewDepthCount = 3
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
    func testImportedUUIDsAreScopedToSheetAndCanMigrateProgress() throws {
        let original = GroupedExpressions.library.stacks[0]
        let card = original.words[0]
        let csv = "stack_id,stack,card_id,japanese,reading,korean\n\(original.id),\(original.title),\(card.id),\(card.japanese),\(card.reading!),\(card.korean)\n"
        let imported = try LibraryImporter.read(Data(csv.utf8), filename: "묶어서 외우는 일본어.csv", namespace: "sheet-link")
        let other = try LibraryImporter.read(Data(csv.utf8), filename: "다른 시트.csv", namespace: "another-sheet")
        XCTAssertNotEqual(imported.stacks[0].id, original.id)
        XCTAssertNotEqual(imported.stacks[0].words[0].id, card.id)
        XCTAssertNotEqual(imported.stacks[0].words[0].id, other.stacks[0].words[0].id)
        var archive = Archive(libraries: [Library(id: imported.id, title: "이전", stacks: [original])])
        var local = Stack(title: original.title, words: [card], sourceID: original.id)
        local.oneWay = true
        local.prepare()
        local.answer(known: true)
        archive.stacks = [local]
        archive.installImportedLibrary(imported)
        XCTAssertEqual(archive.stacks[0].sourceID, imported.stacks[0].id)
        XCTAssertEqual(archive.stacks[0].words[0].id, imported.stacks[0].words[0].id)
        XCTAssertTrue(archive.stacks[0].isComplete)
    }
    func testReadingHeaderAndOptionalCardIDStayStableAcrossRows() throws {
        let first = "stack,ja-JP,ja-JP-reading,ko-KR,en-US\n기본,猫,ねこ,고양이,cat\n"
        let added = "stack,ja-JP,ja-JP-reading,ko-KR,en-US\n기본,犬,いぬ,개,dog\n기본,猫,ねこ,고양이,cat\n"
        let original = try LibraryImporter.read(Data(first.utf8), filename: "단어.csv", namespace: "sheet-a")
        let updated = try LibraryImporter.read(Data(added.utf8), filename: "단어.csv", namespace: "sheet-a")
        XCTAssertEqual(original.stacks[0].words[0].id, updated.stacks[0].words[1].id)
        XCTAssertEqual(updated.stacks[0].words[1].reading, "ねこ")
        XCTAssertEqual(updated.stacks[0].words[1].translations?["en-us"], "cat")
    }
    func testDailyCapKeepsSeenRetriesAndHidesUnseenCards() {
        var stack = Stack(title: "학습", words: (0..<30).map { Word(japanese: "語\($0)", korean: "말\($0)", example: "") })
        stack.oneWay = true
        stack.prepare(poolSize: 20)
        let repeated = stack.queue[0]
        stack.answer(known: false, poolSize: 20)
        stack.restrictToSeen([repeated], poolSize: 20)
        XCTAssertEqual(stack.queue, [repeated])
        XCTAssertEqual(stack.remainingCount, 30)
        stack.prepare(poolSize: 20)
        XCTAssertEqual(stack.queue.count, 20)
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
