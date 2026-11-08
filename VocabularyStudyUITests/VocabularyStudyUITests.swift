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
}
