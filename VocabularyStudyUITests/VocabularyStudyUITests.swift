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
        XCTAssertTrue(app.buttons["answerHard"].exists)
        snapshot("study-answers")
        app.buttons["answerEasy"].tap()
        XCTAssertEqual(remainingCards(app), before.map { $0 - 1 })
        app.buttons["studyClose"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["1 ngày liên tiếp"].waitForExistence(timeout: 5))
        snapshot("today-after-one")
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

    /// Trang của TabView được dựng sẵn khi chưa trượt vào, nên chờ nút bấm được rồi mới chạm.
    private func tapWhenHittable(_ element: XCUIElement) {
        let hittable = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: element)
        wait(for: [hittable], timeout: 5)
        element.tap()
    }

    func testOnboardingSavesChoice() {
        let app = launch(["-ui-testing", "-show-onboarding"])
        XCTAssertTrue(app.buttons["onboardingNext1"].waitForExistence(timeout: 5))
        snapshot("onboarding-1")
        tapWhenHittable(app.buttons["onboardingNext1"])
        let twenty = app.segmentedControls["onboardingNewPerDay"].buttons["20 từ"]
        tapWhenHittable(twenty)
        XCTAssertTrue(twenty.isSelected)
        snapshot("onboarding-2")
        tapWhenHittable(app.buttons["onboardingNext2"])
        XCTAssertTrue(app.buttons["onboardingLater"].waitForExistence(timeout: 5))
        snapshot("onboarding-3")
        tapWhenHittable(app.buttons["onboardingLater"])
        XCTAssertTrue(app.staticTexts["Từ mới, 20"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Từ mới: 20"].waitForExistence(timeout: 5))
    }

    func testOnboardingSkippedAfterDone() {
        let app = launch(["-ui-testing"])
        XCTAssertTrue(app.buttons["startStudy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboardingNext1"].exists)
    }

    // MARK: - Checklist hồi quy (PLAN mục 6)

    /// Học hết thẻ hôm nay → màn kết thúc → streak = 1 → không còn thẻ.
    func testRegressionStudyWholeDay() {
        let app = launch(["-ui-testing", "-seed"])
        XCTAssertTrue(app.staticTexts["Từ mới, 15"].waitForExistence(timeout: 5))
        app.buttons["startStudy"].tap()
        let done = app.staticTexts["Hẹn gặp lại ngày mai."]
        for _ in 0..<40 where !done.exists {
            XCTAssertTrue(app.buttons["revealAnswer"].waitForExistence(timeout: 5))
            app.buttons["revealAnswer"].tap()
            app.buttons["answerEasy"].tap()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        app.buttons["studyClose"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["1 ngày liên tiếp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Từ mới, 0"].exists)
    }

    /// Thêm bộ TOEIC, tạo chủ đề, nhập tay 1 từ, xoá từ, mở flashcard.
    func testRegressionTopics() {
        let app = launch(["-ui-testing"])
        app.tabBars.buttons["Chủ đề"].tap()

        app.buttons["addTopicMenu"].tap()
        app.buttons["Bộ từ TOEIC có sẵn"].tap()
        let addDeck = app.buttons["Thêm 20 từ"].firstMatch
        XCTAssertTrue(addDeck.waitForExistence(timeout: 5))
        addDeck.tap()
        app.buttons["Xong"].tap()

        app.buttons["addTopicMenu"].tap()
        app.buttons["Chủ đề mới"].tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Sách")
        app.alerts.buttons["Thêm"].tap()

        let topic = app.buttons["Sách, 0 từ"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        app.buttons["addWordMenu"].tap()
        app.buttons["Nhập tay"].tap()
        let term = app.textFields["fieldTerm"]
        XCTAssertTrue(term.waitForExistence(timeout: 5))
        term.tap(); term.typeText("generous")
        app.textFields["fieldMeaning"].tap(); app.textFields["fieldMeaning"].typeText("hào phóng")
        app.buttons["Thêm"].tap()
        app.buttons["Xong"].tap()

        let row = app.buttons["word-generous"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["flashcardButton"].tap()
        let flip = app.staticTexts["Chạm để lật"]
        XCTAssertTrue(flip.waitForExistence(timeout: 5))
        flip.tap()
        XCTAssertTrue(app.staticTexts["hào phóng"].waitForExistence(timeout: 5))
        app.buttons["Đóng"].tap()

        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2))
    }

    /// Chụp 3 tab ở chế độ tối + cỡ chữ lớn để xem bố cục (xem ảnh bằng TEST_RUNNER_SNAPSHOT_DIR).
    func testRegressionDarkLargeText() {
        let app = launch(["-ui-testing", "-seed", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        XCTAssertTrue(app.buttons["startStudy"].waitForExistence(timeout: 5))
        snapshot("dark-large-today")
        app.buttons["statsButton"].tap()
        XCTAssertTrue(app.otherElements["statsChart"].waitForExistence(timeout: 5))
        snapshot("dark-large-stats")
        app.navigationBars.buttons.firstMatch.tap()  // quay lại
        for tab in ["Chủ đề", "Ngữ pháp"] {
            app.tabBars.buttons[tab].tap()
            snapshot("dark-large-\(tab)")
        }
    }

    // MARK: - Gõ từ

    private func startTyping(_ app: XCUIApplication) -> XCUIElement {
        app.segmentedControls["studyModePicker"].buttons["Gõ từ"].tap()
        app.buttons["startStudy"].tap()
        let field = app.textFields["typingField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tử tế"].exists)  // thẻ đầu là "kind"
        return field
    }

    func testTypingCorrect() {
        let app = launch(["-ui-testing", "-seed"])
        let field = startTyping(app)
        let before = remainingCards(app)
        field.typeText("Kind")
        app.buttons["typingCheck"].tap()
        XCTAssertTrue(app.staticTexts["kiên nhẫn"].waitForExistence(timeout: 5))  // sang thẻ "patient"
        XCTAssertEqual(remainingCards(app), before.map { $0 - 1 })
    }

    func testTypingWrongShowsAnswer() {
        let app = launch(["-ui-testing", "-seed"])
        let field = startTyping(app)
        let before = remainingCards(app)
        field.typeText("kidn")
        app.buttons["typingCheck"].tap()
        XCTAssertTrue(app.staticTexts["correctAnswer"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["correctAnswer"].label, "kind")
        snapshot("typing-wrong")
        field.typeText("kind")
        app.buttons["typingCheck"].tap()
        XCTAssertTrue(app.staticTexts["kiên nhẫn"].waitForExistence(timeout: 5))
        XCTAssertEqual(remainingCards(app), before)  // quên → thẻ quay lại cuối hàng
    }

    func testChoiceMode() {
        let app = launch(["-ui-testing", "-seed"])
        app.segmentedControls["studyModePicker"].buttons["Chọn nghĩa"].tap()
        app.buttons["startStudy"].tap()
        let right = app.buttons["tử tế"]  // thẻ đầu là "kind"
        XCTAssertTrue(right.waitForExistence(timeout: 5))
        snapshot("choice")
        let before = remainingCards(app)
        right.tap()
        XCTAssertEqual(remainingCards(app), before.map { $0 - 1 })
    }

    // MARK: - Ngữ pháp

    func testGrammarQuizTracksMistakes() {
        let app = launch(["-ui-testing"])
        app.tabBars.buttons["Ngữ pháp"].tap()
        app.staticTexts["Từ loại"].firstMatch.tap()
        app.buttons["startQuiz"].tap()
        var correct = 0
        for i in 1...8 {
            XCTAssertTrue(app.navigationBars["Câu \(i)/8"].waitForExistence(timeout: 5))
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A. '")).firstMatch.tap()
            if app.images["checkmark.circle.fill"].exists && !app.images["xmark.circle.fill"].exists { correct += 1 }
            if i == 1 { snapshot("grammar-answered") }
            app.buttons[i < 8 ? "Câu tiếp" : "Xem kết quả"].tap()
        }
        XCTAssertTrue(app.staticTexts["\(correct)/8 câu đúng"].waitForExistence(timeout: 5))
        app.buttons["Đóng"].tap()
        if correct < 8 {
            XCTAssertTrue(app.buttons["Ôn \(8 - correct) câu sai"].waitForExistence(timeout: 5))
            snapshot("grammar-lesson")
        }
    }

    // MARK: - Thống kê

    func testStatsAfterStudy() {
        let app = launch(["-ui-testing", "-seed"])
        app.buttons["startStudy"].tap()
        for _ in 0..<2 {
            app.buttons["revealAnswer"].tap()
            app.buttons["answerEasy"].tap()
        }
        app.buttons["studyClose"].tap()
        app.buttons["statsButton"].tap()
        XCTAssertTrue(app.staticTexts["Đang học"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["2, Đang học"].exists)  // ô số được gộp thành 1 phần tử
        snapshot("stats")
    }

    // MARK: - Tìm từ

    func testSearchFindsWord() {
        let app = launch(["-ui-testing", "-seed"])
        app.tabBars.buttons["Chủ đề"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("kien nhan")
        XCTAssertTrue(app.buttons["result-patient"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["result-kind"].exists)
        snapshot("search")
        app.buttons["result-patient"].tap()
        XCTAssertTrue(app.buttons["word-patient"].waitForExistence(timeout: 5))  // mở đúng chủ đề "Test"
    }

    func testFilterResetsWhenSearchClosed() {
        let app = launch(["-ui-testing", "-seed"])
        app.tabBars.buttons["Chủ đề"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        app.buttons["Đã thuộc"].tap()
        XCTAssertTrue(app.staticTexts["0 từ"].waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Test, 3 từ"].waitForExistence(timeout: 5))
    }

    func testSwipeRightAnswers() {
        let app = launch(["-ui-testing", "-seed"])
        app.buttons["startStudy"].tap()
        let before = remainingCards(app)
        app.buttons["revealAnswer"].tap()
        let card = app.descendants(matching: .any)["studyCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        snapshot("study-flipped")
        // Kéo theo toạ độ màn hình: swipeRight() trên phần tử nhỏ bên trong thẻ chỉ kéo được vài chục pt.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.45))
        from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.45)))
        let after = NSPredicate { _, _ in self.remainingCards(app) == before.map { $0 - 1 } }
        wait(for: [expectation(for: after, evaluatedWith: nil)], timeout: 5)
    }
}
