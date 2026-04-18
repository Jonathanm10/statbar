import AppKit

private let appDelegate = AppDelegate()
private let application = NSApplication.shared

application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
