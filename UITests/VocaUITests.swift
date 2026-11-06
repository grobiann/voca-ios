import XCTest
@MainActor final class VocaUITests: XCTestCase {
    func testStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        app.buttons["학습 시작"].tap()
        let card = app.descendants(matching: .any)["studyCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        app.buttons["addToReviewDepth"].tap()
        app.buttons["학습 닫기"].tap()
        XCTAssertTrue(app.buttons["반복 학습 시작"].isEnabled)
        screenshot("Store-01-Learn")

        app.buttons["학습 시작"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        screenshot("Store-02-Card-Front")
        card.tap()
        XCTAssertTrue(app.buttons["알았어요"].isEnabled)
        screenshot("Store-03-Card-Back")
        app.buttons["학습 닫기"].tap()

        app.buttons["반복 학습 시작"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        screenshot("Store-04-Review")
        app.buttons["학습 닫기"].tap()

        selectTab("라이브러리", in: app)
        app.buttons["둘러보기"].tap()
        XCTAssertTrue(app.staticTexts["기본 단어장"].waitForExistence(timeout: 10))
        screenshot("Store-05-Library")
        app.staticTexts["기본 단어장"].tap()
        screenshot("Store-06-Decks")
    }
    func testStudySettingsWaitOptionsAndHapticsHelp() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("설정", in: app)
        app.buttons["학습 설정"].tap()
        XCTAssertTrue(app.staticTexts["반복 학습 단계: 5단계"].waitForExistence(timeout: 5))
        app.buttons["카드 햅틱 피드백 설명"].tap()
        XCTAssertTrue(app.alerts["카드 햅틱 피드백"].waitForExistence(timeout: 5))
        app.alerts.buttons["확인"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "반복학습 단계업 대기시간")).firstMatch.tap()
        XCTAssertTrue(app.buttons["1주일"].waitForExistence(timeout: 5))
    }
    func testReviewDepthPromotionAndIndependentStudy() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["학습 시작"].tap()
        let card = app.descendants(matching: .any)["studyCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        app.buttons["addToReviewDepth"].tap()
        XCTAssertTrue(app.staticTexts["1 / 8 완료"].waitForExistence(timeout: 5))
        app.buttons["학습 닫기"].tap()
        app.buttons["반복 학습 시작"].tap()
        for depth in 1...3 {
            XCTAssertTrue(app.staticTexts["일본어 → 한국어 · \(depth)단계"].waitForExistence(timeout: 5))
            card.tap()
            app.buttons["알았어요"].tap()
            XCTAssertTrue(app.staticTexts["반복 학습을 마쳤어요"].waitForExistence(timeout: 5))
            if depth < 3 {
                app.buttons["학습 마치기"].tap()
                app.buttons["반복 학습 시작"].tap()
            }
        }
        XCTAssertTrue(app.staticTexts["반복 학습을 마쳤어요"].waitForExistence(timeout: 5))
        app.buttons["학습 마치기"].tap()
        app.buttons["반복 학습 단어풀"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "반복 학습 완료 · 1개")).firstMatch.waitForExistence(timeout: 5))
    }
    func testStudySettingsCanBeOpenedWithoutRestartingCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["학습 시작"].tap()
        let card = app.descendants(matching: .any)["studyCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        app.buttons["카드 관리"].tap()
        app.buttons["학습 설정"].tap()
        let kana = app.switches["히라가나·가타카나 모드"]
        XCTAssertTrue(kana.waitForExistence(timeout: 5))
        kana.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(kana.value as? String, "1")
        app.buttons["완료"].tap()
        XCTAssertTrue(app.buttons["알았어요"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["알았어요"].isEnabled)
        app.buttons["학습 닫기"].tap()
        selectTab("설정", in: app)
        app.buttons["학습 설정"].tap()
        XCTAssertEqual(app.switches["히라가나·가타카나 모드"].value as? String, "1")
    }
    func testSettingsSearchDeletionAndPrivacy() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("설정", in: app)
        XCTAssertFalse(app.buttons["단어 확인 알림"].exists)
        app.buttons["검색 버튼 설정"].tap()
        app.buttons["검색 사이트 추가"].tap()
        let delete = app.buttons["이 검색 사이트 삭제"]
        if !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertFalse(delete.exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["개인정보 처리방침"].tap()
        XCTAssertTrue(app.staticTexts["기기에 저장하는 정보"].waitForExistence(timeout: 5))
    }
    func testGroupedLibraryCanEnrollWeekdays() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("라이브러리", in: app)
        app.buttons["둘러보기"].tap()
        app.staticTexts["묶어서 외우는 일본어"].tap()
        XCTAssertTrue(app.staticTexts["요일"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["11개 스택 · 122개 단어"].exists)
        app.buttons["내 스택에 추가"].firstMatch.tap()
        XCTAssertTrue(app.buttons["학습 이어가기"].firstMatch.waitForExistence(timeout: 5))
    }
    func testReportCurrentStudyCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["학습 시작"].tap()
        app.buttons["카드 관리"].tap()
        XCTAssertTrue(app.buttons["오류 제보"].waitForExistence(timeout: 5))
        app.buttons["오류 제보"].tap()
        XCTAssertTrue(app.staticTexts["선택한 카드"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["일본어 · 한국어 검색"].exists)
        let message = app.descendants(matching: .any)["reportMessage"].firstMatch
        message.tap()
        message.typeText("학습 중 수정한 뜻")
        app.buttons["제보 저장 및 내 카드 수정"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["학습 중 수정한 뜻"].waitForExistence(timeout: 5))
        app.buttons["학습 닫기"].tap()
        selectTab("설정", in: app)
        app.swipeUp()
        app.buttons["단어 오류 제보함"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "학습 중 수정한 뜻")).firstMatch.waitForExistence(timeout: 5))
    }
    func testRemoveCardsAndStack() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("학습", in: app)
        app.buttons["학습 시작"].tap()
        let sampleWords = ["おはようございます", "楽しみ", "散歩", "ゆっくり"]
        XCTAssertTrue(app.descendants(matching: .any)["studyCard"].firstMatch.waitForExistence(timeout: 5))
        guard let reviewedWord = sampleWords.first(where: { app.staticTexts[$0].exists }) else { XCTFail("첫 카드가 보이지 않아요"); return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["알았어요"].tap()
        XCTAssertTrue(app.staticTexts["1 / 8 완료"].waitForExistence(timeout: 5))
        app.buttons["학습 닫기"].tap()
        app.buttons["내 스택"].tap()
        app.staticTexts["하루를 시작하는 말"].firstMatch.tap()
        app.buttons["\(reviewedWord) 카드 삭제"].tap()
        app.buttons["카드 삭제"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["\(reviewedWord) 카드 삭제"])], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["카드 3개"].exists)
        app.swipeUp()
        app.buttons["내 스택에서 제거"].tap()
        app.buttons["스택과 학습 기록 삭제"].tap()
        XCTAssertTrue(app.staticTexts["내 스택"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["하루를 시작하는 말"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting-resume"]
        app.launch()
        XCTAssertFalse(app.staticTexts["하루를 시작하는 말"].exists)
        selectTab("라이브러리", in: app)
        app.buttons["둘러보기"].tap()
        app.staticTexts["작은 일본어 생활"].tap()
        XCTAssertTrue(app.staticTexts["하루를 시작하는 말"].waitForExistence(timeout: 5))
    }
    func testRemoveDownloadedLibraryKeepsEnrolledStack() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("라이브러리", in: app)
        app.buttons["만들기 또는 가져오기"].tap()
        app.buttons["직접 만들기"].tap()
        let name = app.textFields["라이브러리 이름"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("삭제 테스트")
        app.buttons["만들기"].tap()
        app.staticTexts["삭제 테스트"].tap()
        app.swipeUp()
        app.buttons["이 라이브러리 제거"].tap()
        app.buttons["이 기기에서 라이브러리 제거"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["삭제 테스트"])], timeout: 5), .completed)
        app.terminate()
        app.launchArguments = ["--uitesting-resume"]
        app.launch()
        selectTab("라이브러리", in: app)
        XCTAssertFalse(app.staticTexts["삭제 테스트"].exists)
        selectTab("학습", in: app)
        app.buttons["내 스택"].tap()
        XCTAssertTrue(app.staticTexts["하루를 시작하는 말"].exists)
    }
    func testPoolCopyAndReportPersistence() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("설정", in: app)
        XCTAssertTrue(app.steppers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["학습 풀 크기: 20개"].exists)
        app.steppers.firstMatch.buttons["Increment"].tap()
        XCTAssertTrue(app.staticTexts["학습 풀 크기: 21개"].exists)
        selectTab("학습", in: app)
        app.buttons["학습 시작"].tap()
        XCTAssertFalse(app.buttons["알았어요"].isEnabled)
        XCTAssertTrue(app.staticTexts["학습 풀 4/21 · 남은 8"].exists)
        app.buttons["학습 닫기"].tap()
        selectTab("라이브러리", in: app)
        app.buttons["둘러보기"].tap()
        app.staticTexts["작은 일본어 생활"].tap()
        app.buttons["라이브러리 오류 제보"].tap()
        app.buttons.containing(.staticText, identifier: "おはようございます").firstMatch.tap()
        app.swipeUp()
        let field = app.descendants(matching: .any)["reportMessage"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Meaning correction")
        app.buttons["제보 저장 및 내 카드 수정"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting-resume"]
        app.launch()
        selectTab("설정", in: app)
        XCTAssertTrue(app.staticTexts["학습 풀 크기: 21개"].exists)
        app.swipeUp()
        app.buttons["단어 오류 제보함"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Meaning correction")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["제보 공유"].exists)
        screenshot("12-Word-Report")
    }
    func testStudyAndLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["학습 시작"].waitForExistence(timeout: 10))
        screenshot("01-Learn")
        app.buttons["학습 시작"].tap()
        let sampleWords = ["おはようございます", "楽しみ", "散歩", "ゆっくり"]
        XCTAssertTrue(app.descendants(matching: .any)["studyCard"].firstMatch.waitForExistence(timeout: 5))
        guard let firstWord = sampleWords.first(where: { app.staticTexts[$0].isHittable }) else { XCTFail("첫 카드가 보이지 않아요"); return }
        XCTAssertTrue(app.buttons["\(firstWord) Google 검색"].exists)
        XCTAssertFalse(app.buttons["알았어요"].isEnabled)
        screenshot("02-Card-Front")
        app.staticTexts[firstWord].tap()
        XCTAssertTrue(app.buttons["알았어요"].isEnabled)
        XCTAssertTrue(app.staticTexts["0 / 8 완료"].exists)
        screenshot("03-Card-Back")
        if app.windows.firstMatch.frame.width > 600 {
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.descendants(matching: .any)["studyCard"].firstMatch.isHittable)
            screenshot("13-iPad-Landscape")
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.52)))
        XCTAssertTrue(app.staticTexts["0 / 8 완료"].waitForExistence(timeout: 5))
        guard let secondWord = sampleWords.first(where: { $0 != firstWord && app.staticTexts[$0].exists }) else { XCTFail("다음 카드가 보이지 않아요"); return }
        XCTAssertTrue(app.staticTexts["0 / 8 완료"].exists)
        app.staticTexts[secondWord].tap()
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.52)))
        XCTAssertTrue(app.staticTexts["1 / 8 완료"].waitForExistence(timeout: 5))
        app.buttons["이전 응답 취소"].tap()
        XCTAssertTrue(app.staticTexts["0 / 8 완료"].exists)
        app.buttons["학습 닫기"].tap()
        selectTab("라이브러리", in: app)
        app.buttons["둘러보기"].tap()
        XCTAssertTrue(app.staticTexts["작은 일본어 생활"].waitForExistence(timeout: 5))
        screenshot("04-Library")
        app.staticTexts["작은 일본어 생활"].tap()
        app.swipeUp()
        app.buttons["내 스택에 추가"].tap()
        XCTAssertFalse(app.buttons["내 스택에 추가"].exists)
        XCTAssertTrue(app.buttons["학습 이어가기"].firstMatch.exists)
        screenshot("08-Stack-Path")
        selectTab("설정", in: app)
        app.buttons["학습 설정"].tap()
        XCTAssertTrue(app.staticTexts["앞면에 히라가나 표시"].waitForExistence(timeout: 5))
        screenshot("05-Account")
    }
    func testCompletionAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["학습 시작"].tap()
        for index in 0..<8 {
            XCTAssertTrue(app.staticTexts["\(index) / 8 완료"].waitForExistence(timeout: 5))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let known = app.buttons["알았어요"]
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: known)
            XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
            if index == 0 { screenshot("06-Stable-Answer") }
            known.tap()
        }
        XCTAssertTrue(app.staticTexts["스택을 모두 익혔어요!"].waitForExistence(timeout: 5))
        screenshot("07-Completed")
        app.buttons["학습 마치기"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting-resume"]
        app.launch()
        XCTAssertTrue(app.buttons["학습 시작"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["학습 시작"].isEnabled)
    }
    func testLiveSheetImport() throws {
        guard ProcessInfo.processInfo.environment["VOCA_LIVE_SHEET_TEST"] == "1" else {
            throw XCTSkip("Opt-in network integration test: TEST_RUNNER_VOCA_LIVE_SHEET_TEST=1")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        selectTab("라이브러리", in: app)
        app.buttons["만들기 또는 가져오기"].tap()
        app.buttons["Google Sheets 링크"].tap()
        app.buttons["공개 단어장 링크 사용"].tap()
        app.buttons["시트 목록 확인"].tap()
        XCTAssertTrue(app.buttons["가져오기"].waitForExistence(timeout: 30))
        screenshot("09-Sheet-Selection")
        app.buttons["가져오기"].tap()
        let importedCount = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "스택 [1-9][0-9]*개   ·   단어 [1-9][0-9]*개")).firstMatch
        XCTAssertTrue(importedCount.waitForExistence(timeout: 35))
        app.staticTexts["N5"].tap()
        XCTAssertTrue(app.staticTexts["N5 단어 001"].waitForExistence(timeout: 5))
        app.buttons["내 스택에 추가"].firstMatch.tap()
        XCTAssertTrue(app.buttons["학습 이어가기"].waitForExistence(timeout: 5))
        screenshot("10-JLPT-Stack-Path")
        app.buttons["학습 이어가기"].tap()
        app.buttons["학습 시작"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["studyCard"].firstMatch.waitForExistence(timeout: 5))
        let progress = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "0 / [1-9][0-9]* 완료")).firstMatch
        XCTAssertTrue(progress.exists)
        let total = Int(progress.label.split(separator: " ").dropFirst(2).first ?? "0") ?? 0
        XCTAssertGreaterThan(total, 0)
        XCTAssertTrue(app.staticTexts["학습 풀 \(min(20, total / 2))/20 · 남은 \(total)"].exists)
        screenshot("11-JLPT-Study-Pool")
    }
    private func selectTab(_ title: String, in app: XCUIApplication) {
        let phoneTab = app.tabBars.buttons[title]
        if phoneTab.exists { phoneTab.tap(); return }
        // iPadOS presents floating tabs as cells, rather than a UITabBar.
        let tabletTab = app.cells[title]
        if tabletTab.exists { tabletTab.tap(); return }
        app.buttons[title].firstMatch.tap()
    }
    private func screenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
