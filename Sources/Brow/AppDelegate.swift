import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let displayMode = DisplayModeSwitcher()
    private var overlay: OverlayController?
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController(preferences: preferences, displayMode: displayMode)
        statusMenu = StatusMenu(preferences: preferences, displayMode: displayMode)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        overlay?.rebuild()
    }
}
