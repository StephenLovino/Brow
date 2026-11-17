import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let displayMode = DisplayModeSwitcher()
    private var overlay: OverlayController?
    private var statusMenu: StatusMenu?
    private var updater: Updater?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let updater = Updater()
        self.updater = updater
        overlay = OverlayController(preferences: preferences, displayMode: displayMode)
        statusMenu = StatusMenu(preferences: preferences, displayMode: displayMode, updater: updater)

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
