import XCTest
@testable import MenuBarStats

@MainActor
final class PreferencesWindowControllerTests: XCTestCase {
    func testPreferencesWindowCanOpenCloseAndReopen() {
        let presenter = AppKitPreferencesPresenter(
            viewModel: PreferencesViewModel(
                settingsStore: StubSettingsStore(),
                launchAtLoginController: StubLaunchAtLoginController()
            )
        )

        presenter.show()
        let window = presenter.presentedWindow

        XCTAssertNotNil(window)
        XCTAssertTrue(window?.isVisible == true)

        window?.performClose(nil)
        XCTAssertFalse(window?.isVisible ?? true)

        presenter.show()
        XCTAssertTrue(window?.isVisible == true)
        XCTAssertTrue(window === presenter.presentedWindow)

        window?.close()
    }
}
