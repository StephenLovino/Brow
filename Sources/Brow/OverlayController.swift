import AppKit
import SwiftUI
import Combine

final class OverlayState: ObservableObject {
    @Published var drawerOpen = false
    /// True while the user holds Option to see what is under the band.
    @Published var bandHidden = false
}

/// Owns the click-through window that blacks out the notch and hangs the widget drawer below it.
final class OverlayController {
    /// Extra black on each side of the notch in `.notch` mode, so its edges disappear.
    static let earWidth: CGFloat = 70
    static let drawerSize = CGSize(width: 340, height: 72)

    private let preferences: Preferences
    private let displayMode: DisplayModeSwitcher
    private let state = OverlayState()
    private var window: NSWindow?
    private var geometry: NotchGeometry?
    private var bandHeight: CGFloat = 0
    private var pollTimer: Timer?
    private var pendingClose: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences, displayMode: DisplayModeSwitcher) {
        self.preferences = preferences
        self.displayMode = displayMode

        preferences.objectWillChange
            .sink { [weak self] in
                // objectWillChange fires before the new value lands.
                DispatchQueue.main.async { self?.rebuild() }
            }
            .store(in: &cancellables)

        rebuild()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func rebuild() {
        // Switching modes fires a screen change, which calls rebuild again with the new geometry.
        displayMode.setActive(preferences.pushBelowNotch)

        guard let screen = NotchGeometry.preferredScreen() else { return }
        let geo = NotchGeometry(screen: screen)
        geometry = geo
        // While pushed below the notch, macOS already blacks out the strip, so the drawer
        // hangs straight from the top of the menu bar instead of from a band.
        bandHeight = displayMode.isActive ? 0 : geo.height

        // The window spans the whole screen width so it can also round off the screen's top
        // corners; it's transparent and click-through everywhere it doesn't draw.
        let cornerRadius = preferences.cornerStyle.radius
        let height = max(bandHeight + Self.drawerSize.height, cornerRadius)
        let frame = CGRect(
            x: geo.screenFrame.minX,
            y: geo.screenFrame.maxY - height,
            width: geo.screenFrame.width,
            height: height
        )

        let window = self.window ?? makeWindow()
        let hostingView = NSHostingView(rootView: OverlayView(
            state: state,
            bandWidth: bandWidth(for: geo),
            bandHeight: bandHeight,
            drawerSize: Self.drawerSize,
            roundedBand: preferences.bandMode == .notch,
            notchOffset: geo.centerX - geo.screenFrame.midX,
            cornerRadius: cornerRadius
        ))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        self.window = window

        state.drawerOpen = preferences.drawerMode == .always
    }

    private func bandWidth(for geo: NotchGeometry) -> CGFloat {
        switch preferences.bandMode {
        case .notch:
            return geo.effectiveNotchWidth + Self.earWidth * 2
        case .fullWidth:
            // Centered on the notch, so it must reach the farther screen edge on both sides.
            let reach = max(geo.centerX - geo.screenFrame.minX, geo.screenFrame.maxX - geo.centerX)
            return reach * 2
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return window
    }

    // MARK: - Hover and Option-peek

    private func poll() {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if state.bandHidden != optionHeld {
            state.bandHidden = optionHeld
        }

        guard preferences.drawerMode == .onHover, let geo = geometry else { return }

        if hoverZone(for: geo).contains(NSEvent.mouseLocation) {
            pendingClose?.cancel()
            pendingClose = nil
            if !state.drawerOpen {
                setDrawer(open: true)
            }
        } else if state.drawerOpen, pendingClose == nil {
            let close = DispatchWorkItem { [weak self] in
                self?.pendingClose = nil
                self?.setDrawer(open: false)
            }
            pendingClose = close
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: close)
        }
    }

    private func hoverZone(for geo: NotchGeometry) -> CGRect {
        // Only the area around the notch opens the drawer, even in full-width mode,
        // so moving along the menu bar doesn't keep popping it open.
        let width = geo.effectiveNotchWidth + Self.earWidth * 2
        let top = geo.screenFrame.maxY + 1 // the cursor can sit on the very top edge
        var zone = CGRect(x: geo.centerX - width / 2, y: top - geo.height - 1, width: width, height: geo.height + 1)

        if state.drawerOpen {
            let drawer = Self.drawerSize
            zone = zone.union(CGRect(
                x: geo.centerX - drawer.width / 2,
                y: top - bandHeight - drawer.height - 1,
                width: drawer.width,
                height: drawer.height
            ))
        }
        return zone
    }

    private func setDrawer(open: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            state.drawerOpen = open
        }
    }
}
