import Foundation

enum Logger {
    static func error(_ message: String) {
        NSLog("MenuBarStats: %@", message)
    }
}
