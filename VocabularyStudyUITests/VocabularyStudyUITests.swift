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

    /// Lưu ảnh màn hình ra máy Mac khi chạy với TEST_RUNNER_SNAPSHOT_DIR=<thư mục> (để xem giao diện). Bình thường không làm gì.
    private func snapshot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
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

    func testDeleteTopicAsksConfirmation() {
        let app = launch(["-ui-testing", "-seed"])
        app.tabBars.buttons["Chủ đề"].tap()
        let topic = app.buttons["Test, 3 từ"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))

        topic.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Xoá \"Test\" và 3 từ bên trong. Không thể hoàn tác."].waitForExistence(timeout: 5))
        app.otherElements["PopoverDismissRegion"].tap()  // iOS 26: huỷ bằng cách chạm ra ngoài popover
        XCTAssertTrue(app.buttons["confirmDeleteTopic"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(topic.exists)

        topic.swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons.matching(identifier: "confirmDeleteTopic").firstMatch.tap()
        XCTAssertTrue(topic.waitForNonExistence(timeout: 5))
    }

    func testChangeNewWordLimit() {
        let app = launch(["-ui-testing", "-seed"])
        XCTAssertTrue(app.staticTexts["Từ mới, 15"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()
        let minus = app.steppers["newPerDayStepper"].buttons.element(boundBy: 0)  // nút giảm
        XCTAssertTrue(minus.waitForExistence(timeout: 5))
        snapshot("settings")
        for _ in 0..<10 { minus.tap() }
        app.buttons["settingsDone"].tap()
        XCTAssertTrue(app.staticTexts["Từ mới, 5"].waitForExistence(timeout: 5))
    }
}
