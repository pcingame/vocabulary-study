import XCTest

@MainActor
final class VocabularyStudyUITests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func testAppLaunches() {
        let app = launch(["-ui-testing"])
        for tab in ["Hôm nay", "Chủ đề", "Ngữ pháp"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5), "thiếu tab \(tab)")
        }
    }

    func testSeedCreatesTopic() {
        let app = launch(["-ui-testing", "-seed"])
        app.tabBars.buttons["Chủ đề"].tap()
        XCTAssertTrue(app.buttons["Test, 3 từ"].waitForExistence(timeout: 5))
        // chế độ test không xin quyền thông báo
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists)
    }

    /// Số trên tiêu đề "Còn N thẻ" của màn học.
    private func remainingCards(_ app: XCUIApplication) -> Int? {
        let title = app.navigationBars.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Còn '")).firstMatch
        guard title.waitForExistence(timeout: 5) else { return nil }
        return Int(title.label.split(separator: " ")[1])
    }

    func testStudyOneCard() {
        let app = launch(["-ui-testing", "-seed"])
        app.buttons["startStudy"].tap()
        let before = remainingCards(app)
        XCTAssertNotNil(before)
        app.buttons["revealAnswer"].tap()
        app.buttons["answerRemember"].tap()
        XCTAssertEqual(remainingCards(app), before.map { $0 - 1 })
        app.buttons["studyClose"].tap()
        XCTAssertTrue(app.staticTexts["1 ngày liên tiếp"].waitForExistence(timeout: 5))
    }

    /// Mở chủ đề "Test" rồi mở form sửa từ "kind".
    private func kindRow(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "word-kind").firstMatch
    }

    private func kindRowHas(_ app: XCUIApplication, _ text: String) -> Bool {
        kindRow(app).label.contains(text)
    }

    private func openEditKind(_ app: XCUIApplication) {
        app.tabBars.buttons["Chủ đề"].tap()
        app.buttons["Test, 3 từ"].tap()
        kindRow(app).tap()
        XCTAssertTrue(app.buttons["saveWord"].waitForExistence(timeout: 5))
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        field.typeText(text)
    }

    func testEditWord() {
        let app = launch(["-ui-testing", "-seed"])
        openEditKind(app)
        replaceText(app.textFields["fieldMeaning"], with: "nghia moi")
        app.buttons["saveWord"].tap()
        XCTAssertTrue(kindRow(app).waitForExistence(timeout: 5))
        XCTAssertTrue(kindRowHas(app, "adj, nghia moi"))
        XCTAssertFalse(kindRowHas(app, "adj, tử tế"))
    }

    func testCancelEditKeepsWord() {
        let app = launch(["-ui-testing", "-seed"])
        openEditKind(app)
        replaceText(app.textFields["fieldMeaning"], with: "nghia moi")
        app.buttons["cancelEdit"].tap()
        XCTAssertTrue(kindRow(app).waitForExistence(timeout: 5))
        XCTAssertTrue(kindRowHas(app, "adj, tử tế"))
        XCTAssertFalse(kindRowHas(app, "adj, nghia moi"))
    }

    func testSaveDisabledWhenTermEmpty() {
        let app = launch(["-ui-testing", "-seed"])
        openEditKind(app)
        replaceText(app.textFields["fieldTerm"], with: "")
        XCTAssertFalse(app.buttons["saveWord"].isEnabled)
    }
}
