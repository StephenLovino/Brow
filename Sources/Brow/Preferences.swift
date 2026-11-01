import Foundation
import Combine

enum BandMode: String, CaseIterable {
    case notch
    case fullWidth

    var title: String {
        switch self {
        case .notch: "Around the notch"
        case .fullWidth: "Full width"
        }
    }
}

enum DrawerMode: String, CaseIterable {
    case onHover
    case always
    case off

    var title: String {
        switch self {
        case .onHover: "Show on hover"
        case .always: "Always show"
        case .off: "Hidden"
        }
    }
}

enum CornerStyle: String, CaseIterable {
    case off
    case small
    case medium
    case large

    var title: String {
        switch self {
        case .off: "Off"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var radius: CGFloat {
        switch self {
        case .off: 0
        case .small: 8
        case .medium: 12
        case .large: 18
        }
    }
}

final class Preferences: ObservableObject {
    private enum Key {
        static let bandMode = "bandMode"
        static let drawerMode = "drawerMode"
        static let pushBelowNotch = "pushBelowNotch"
        static let cornerStyle = "cornerStyle"
    }

    @Published var bandMode: BandMode {
        didSet { UserDefaults.standard.set(bandMode.rawValue, forKey: Key.bandMode) }
    }

    @Published var drawerMode: DrawerMode {
        didSet { UserDefaults.standard.set(drawerMode.rawValue, forKey: Key.drawerMode) }
    }

    /// Move the menu bar and all windows below the notch by switching the built-in display mode.
    @Published var pushBelowNotch: Bool {
        didSet { UserDefaults.standard.set(pushBelowNotch, forKey: Key.pushBelowNotch) }
    }

    /// Rounds the screen's top corners, which turn square once everything is pushed below the notch.
    @Published var cornerStyle: CornerStyle {
        didSet { UserDefaults.standard.set(cornerStyle.rawValue, forKey: Key.cornerStyle) }
    }

    init() {
        let defaults = UserDefaults.standard
        bandMode = BandMode(rawValue: defaults.string(forKey: Key.bandMode) ?? "") ?? .notch
        drawerMode = DrawerMode(rawValue: defaults.string(forKey: Key.drawerMode) ?? "") ?? .onHover
        pushBelowNotch = defaults.bool(forKey: Key.pushBelowNotch)
        cornerStyle = CornerStyle(rawValue: defaults.string(forKey: Key.cornerStyle) ?? "") ?? .medium
    }
}
