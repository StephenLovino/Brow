import AppKit

/// Where the camera housing sits on a screen, in global screen coordinates.
struct NotchGeometry {
    /// Width used for the band when the screen has no notch.
    static let fallbackNotchWidth: CGFloat = 180

    let screenFrame: CGRect
    /// Height of the notch, or of the menu bar on screens without one.
    let height: CGFloat
    /// Zero when the screen has no notch.
    let notchWidth: CGFloat
    let centerX: CGFloat

    var hasNotch: Bool { notchWidth > 0 }
    var effectiveNotchWidth: CGFloat { hasNotch ? notchWidth : Self.fallbackNotchWidth }

    init(screen: NSScreen) {
        let frame = screen.frame
        screenFrame = frame

        let topInset = screen.safeAreaInsets.top
        if topInset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            // The notch is whatever the two usable top corners leave between them.
            height = topInset
            notchWidth = frame.width - left.width - right.width
            centerX = frame.minX + left.width + notchWidth / 2
        } else {
            let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
            height = menuBarHeight > 0 ? menuBarHeight : 24
            notchWidth = 0
            centerX = frame.midX
        }
    }

    /// The notched display if there is one, then the built-in display (it loses its notch
    /// while pushed below it), otherwise the main display.
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.screens.first { $0.displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false }
            ?? NSScreen.main
    }
}
