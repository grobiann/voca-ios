import XCTest
@MainActor final class VocaUITests: XCTestCase {
    func testActualNotificationTapOpensQuickReview() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["계정"].tap()
        app.buttons["microReviewSettings"].tap()
        let testButton = app.buttons["5초 후 테스트 알림"]
        for _ in 0..<5 where !testButton.isHittable { app.swipeUp() }
        XCTAssertTrue(testButton.isHittable)
        testButton.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == '허용'")).firstMatch
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        XCUIDevice.shared.press(.home)
        let banner = springboard.staticTexts["1-3-3 풀이 비었어요"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        banner.tap()
        XCTAssertTrue(app.staticTexts["1-3-3 풀이 비었어요"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["학습 화면으로 돌아가기"].exists)
    }
    func testNotificationColdLaunchOpensQuickReview() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-notification-open"]
        app.launch()
        XCTAssertTrue(app.staticTexts["1-3-3 풀이 비었어요"].waitForExistence(timeout: 10))
        app.buttons["학습 화면으로 돌아가기"].tap()
        XCTAssertTrue(app.buttons["학습 시작"].waitForExistence(timeout: 5))
    }
    func testReportCurrentStudyCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["학습 시작"].tap()
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
        app.tabBars.buttons["계정"].tap()
        app.swipeUp()
        app.buttons["단어 오류 제보함"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "학습 중 수정한 뜻")).firstMatch.waitForExistence(timeout: 5))
    }
    func testMicroReviewCompletesThreeChecks() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["학습 시작"].tap()
        XCTAssertTrue(app.buttons["1-3-3에 담기"].waitForExistence(timeout: 5))
        app.buttons["1-3-3에 담기"].tap()
        app.buttons["학습 닫기"].tap()
        app.tabBars.buttons["계정"].tap()
        app.buttons["microReviewSettings"].tap()
        XCTAssertTrue(app.staticTexts["1-3-3 풀 · 1개"].waitForExistence(timeout: 5))
        for count in 0..<3 {
            app.buttons["지금 1-3-3 확인"].tap()
            XCTAssertTrue(app.staticTexts["이 단어 학습 완료 \(count)/3회"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["이번 카드 1 / 1"].exists)
            XCTAssertFalse(app.buttons["알았어요"].isEnabled)
            let card = app.descendants(matching: .any)["microReviewCard"].firstMatch
            card.tap()
            XCTAssertTrue(app.buttons["알았어요"].isEnabled)
            XCTAssertFalse(app.staticTexts["先生、おはようございます。"].exists)
            if count == 0 {
                card.swipeLeft()
                XCTAssertTrue(app.buttons["microFinishReview"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.staticTexts["26초 후 마침"].waitForExistence(timeout: 6))
                XCTAssertTrue(app.buttons["학습 시작"].waitForExistence(timeout: 30))
                app.tabBars.buttons["계정"].tap()
                app.buttons["지금 1-3-3 확인"].tap()
                XCTAssertTrue(app.staticTexts["이 단어 학습 완료 0/3회"].waitForExistence(timeout: 5))
                card.tap()
            }
            if count == 1 { card.swipeRight() } else { app.buttons["알았어요"].tap() }
            XCTAssertTrue(app.buttons["microFinishReview"].waitForExistence(timeout: 5))
            XCTAssertGreaterThan(app.buttons["microFinishReview"].frame.height, 300)
            app.buttons["microFinishReview"].tap()
            XCTAssertTrue(app.buttons["학습 시작"].waitForExistence(timeout: 8))
            app.tabBars.buttons["계정"].tap()
        }
        XCTAssertTrue(app.staticTexts["학습완료단어목록 · 1개"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1-3-3 풀 · 0개"].exists)
    }
    func testRemoveCardsAndStack() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["학습"].tap()
        app.buttons["학습 시작"].tap()
        let sampleWords = ["おはようございます", "楽しみ", "散歩", "ゆっくり"]
        XCTAssertTrue(app.buttons["일본어 복사"].waitForExistence(timeout: 5))
        guard let reviewedWord = sampleWords.first(where: { app.staticTexts[$0].exists }) else { XCTFail("첫 카드가 보이지 않아요"); return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["알았어요"].tap()
        XCTAssertTrue(app.staticTexts["1 / 8 완료"].waitForExistence(timeout: 5))
        app.buttons["학습 닫기"].tap()
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
        app.tabBars.buttons["라이브러리"].tap()
        app.buttons["둘러보기"].tap()
        app.staticTexts["작은 일본어 생활"].tap()
        XCTAssertTrue(app.staticTexts["하루를 시작하는 말"].waitForExistence(timeout: 5))
    }
    func testRemoveDownloadedLibraryKeepsEnrolledStack() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["라이브러리"].tap()
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
        app.tabBars.buttons["라이브러리"].tap()
        XCTAssertFalse(app.staticTexts["삭제 테스트"].exists)
        app.tabBars.buttons["학습"].tap()
        XCTAssertTrue(app.staticTexts["하루를 시작하는 말"].exists)
    }
    func testPoolCopyAndReportPersistence() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["계정"].tap()
        XCTAssertTrue(app.steppers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["학습 풀 크기: 20개"].exists)
        app.steppers.firstMatch.buttons["Increment"].tap()
        XCTAssertTrue(app.staticTexts["학습 풀 크기: 21개"].exists)
        app.tabBars.buttons["학습"].tap()
        app.buttons["학습 시작"].tap()
        app.buttons["일본어 복사"].tap()
        XCTAssertTrue(app.buttons["일본어 복사 완료"].exists)
        XCTAssertFalse(app.buttons["알았어요"].isEnabled)
        XCTAssertTrue(app.staticTexts["학습 풀 4/21 · 남은 8"].exists)
        app.buttons["학습 닫기"].tap()
        app.tabBars.buttons["라이브러리"].tap()
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
        app.tabBars.buttons["계정"].tap()
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
        XCTAssertTrue(app.buttons["일본어 복사"].waitForExistence(timeout: 5))
        guard let firstWord = sampleWords.first(where: { app.staticTexts[$0].isHittable }) else { XCTFail("첫 카드가 보이지 않아요"); return }
        XCTAssertTrue(app.buttons["\(firstWord) 구글 검색"].exists)
        XCTAssertFalse(app.buttons["알았어요"].isEnabled)
        screenshot("02-Card-Front")
        app.staticTexts[firstWord].tap()
        XCTAssertTrue(app.buttons["알았어요"].isEnabled)
        XCTAssertTrue(app.staticTexts["0 / 8 완료"].exists)
        screenshot("03-Card-Back")
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
        app.tabBars.buttons["라이브러리"].tap()
        app.buttons["둘러보기"].tap()
        XCTAssertTrue(app.staticTexts["작은 일본어 생활"].waitForExistence(timeout: 5))
        screenshot("04-Library")
        app.staticTexts["작은 일본어 생활"].tap()
        app.swipeUp()
        app.buttons["내 스택에 추가"].tap()
        XCTAssertFalse(app.buttons["내 스택에 추가"].exists)
        XCTAssertTrue(app.buttons["학습 이어가기"].firstMatch.exists)
        screenshot("08-Stack-Path")
        app.tabBars.buttons["계정"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "양방향 정답")).firstMatch.waitForExistence(timeout: 5))
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
        app.tabBars.buttons["라이브러리"].tap()
        app.buttons["만들기 또는 가져오기"].tap()
        app.buttons["Google Sheets 링크"].tap()
        app.buttons["JLPT N5–N1 단어장 링크 사용"].tap()
        app.buttons["시트 목록 확인"].tap()
        XCTAssertTrue(app.buttons["가져오기"].waitForExistence(timeout: 30))
        screenshot("09-Sheet-Selection")
        app.buttons["가져오기"].tap()
        XCTAssertTrue(app.staticTexts["스택 34개   ·   단어 674개"].waitForExistence(timeout: 35))
        app.staticTexts["N5"].tap()
        XCTAssertTrue(app.staticTexts["N5 단어 001"].waitForExistence(timeout: 5))
        app.buttons["내 스택에 추가"].firstMatch.tap()
        XCTAssertTrue(app.buttons["학습 이어가기"].waitForExistence(timeout: 5))
        screenshot("10-JLPT-Stack-Path")
        app.buttons["학습 이어가기"].tap()
        app.buttons["학습 시작"].tap()
        XCTAssertTrue(app.buttons["일본어 복사"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["학습 풀 20/20 · 남은 40"].exists)
        screenshot("11-JLPT-Study-Pool")
    }
    private func screenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
