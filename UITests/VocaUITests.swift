import XCTest
@MainActor final class VocaUITests: XCTestCase {
    func testStudyAndLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["학습 시작"].waitForExistence(timeout: 10))
        screenshot("01-Learn")
        app.buttons["학습 시작"].tap()
        XCTAssertTrue(app.staticTexts["おはようございます"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["알았어요"].isEnabled)
        screenshot("02-Card-Front")
        app.staticTexts["おはようございます"].tap()
        XCTAssertTrue(app.buttons["알았어요"].isEnabled)
        XCTAssertTrue(app.staticTexts["좋은 아침이에요"].exists)
        screenshot("03-Card-Back")
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.52)))
        XCTAssertTrue(app.staticTexts["楽しみ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 / 8 완료"].exists)
        app.staticTexts["楽しみ"].tap()
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
        app.buttons["내 스택에 추가"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "내 스택에 등록됨")).count, 2)
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
    private func screenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
