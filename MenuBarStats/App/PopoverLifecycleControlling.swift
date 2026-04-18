import AppKit
import SwiftUI

@MainActor
protocol PopoverPresenting: AnyObject {
    var isShown: Bool { get }
    var onDidClose: (() -> Void)? { get set }
    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge)
    func close()
}

@MainActor
final class AppKitPopoverPresenter: NSObject, PopoverPresenting, NSPopoverDelegate {
    private let popover: NSPopover
    var onDidClose: (() -> Void)?

    init(rootView: AnyView, contentSize: NSSize) {
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = contentSize
        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.delegate = self
    }

    var isShown: Bool {
        popover.isShown
    }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        popover.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    func close() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        onDidClose?()
    }
}
