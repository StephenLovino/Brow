import AppKit
import CoreGraphics

/// Switches the built-in display to its "below the notch" mode: the same width, minus the notch strip.
/// macOS then lays out the menu bar and every window under the notch and leaves the strip black.
final class DisplayModeSwitcher {
    private(set) var isActive = false

    /// Whether the toggle can do anything on this Mac right now.
    var isAvailable: Bool {
        isActive || builtInDisplay.flatMap(belowNotchMode(for:)) != nil
    }

    func setActive(_ active: Bool) {
        guard active != isActive, let display = builtInDisplay else { return }

        if active {
            guard let mode = belowNotchMode(for: display) else { return }
            // CGDisplaySetDisplayMode only changes the mode for as long as Brow runs,
            // so quitting (or crashing) puts the user's own resolution back.
            if CGDisplaySetDisplayMode(display, mode, nil) == .success {
                isActive = true
            }
        } else {
            CGRestorePermanentDisplayConfiguration()
            isActive = false
        }
    }

    private var builtInDisplay: CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// The tallest mode with the current width that is shorter than the current one,
    /// but only while the screen still reaches up beside the notch.
    private func belowNotchMode(for display: CGDirectDisplayID) -> CGDisplayMode? {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == display }),
              screen.safeAreaInsets.top > 0,
              let current = CGDisplayCopyDisplayMode(display)
        else { return nil }

        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] ?? []
        return modes
            .filter {
                $0.isUsableForDesktopGUI()
                    && $0.width == current.width
                    && $0.pixelWidth == current.pixelWidth
                    && $0.height < current.height
            }
            .max { ($0.height, $0.refreshRate) < ($1.height, $1.refreshRate) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
