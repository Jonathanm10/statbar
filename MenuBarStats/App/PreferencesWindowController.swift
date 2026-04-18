import AppKit
import SwiftUI

@MainActor
protocol PreferencesPresenting: AnyObject {
    func show()
}

@MainActor
final class AppKitPreferencesPresenter: PreferencesPresenting {
    private let viewModel: PreferencesViewModel
    private var windowController: NSWindowController?

    init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        if windowController == nil {
            windowController = makeWindowController()
        }

        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var presentedWindow: NSWindow? {
        windowController?.window
    }

    private func makeWindowController() -> NSWindowController {
        let view = PreferencesView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = controller
        window.center()
        window.isReleasedWhenClosed = false
        return NSWindowController(window: window)
    }
}

@MainActor
final class NoopPreferencesPresenter: PreferencesPresenting {
    func show() {}
}
