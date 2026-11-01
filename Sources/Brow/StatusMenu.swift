import AppKit

final class StatusMenu: NSObject, NSMenuDelegate {
    private let preferences: Preferences
    private let displayMode: DisplayModeSwitcher
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(preferences: Preferences, displayMode: DisplayModeSwitcher) {
        self.preferences = preferences
        self.displayMode = displayMode
        super.init()

        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Brow")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let push = ActionItem("Push everything below the notch", checked: displayMode.isActive) { [preferences] in
            preferences.pushBelowNotch.toggle()
        }
        push.isEnabled = displayMode.isAvailable
        menu.addItem(push)
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: "Black band"))
        for mode in BandMode.allCases {
            menu.addItem(ActionItem(mode.title, checked: preferences.bandMode == mode) { [preferences] in
                preferences.bandMode = mode
            })
        }

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Widgets"))
        for mode in DrawerMode.allCases {
            menu.addItem(ActionItem(mode.title, checked: preferences.drawerMode == mode) { [preferences] in
                preferences.drawerMode = mode
            })
        }

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Rounded top corners"))
        for style in CornerStyle.allCases {
            menu.addItem(ActionItem(style.title, checked: preferences.cornerStyle == style) { [preferences] in
                preferences.cornerStyle = style
            })
        }

        menu.addItem(.separator())
        let hint = NSMenuItem(title: "Hold ⌥ to peek under the band", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Brow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}

private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func fire() {
        handler()
    }
}
