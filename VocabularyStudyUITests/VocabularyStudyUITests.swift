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
        let app = launch()
        for tab in ["Hôm nay", "Chủ đề", "Ngữ pháp"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5), "thiếu tab \(tab)")
        }
    }
}
