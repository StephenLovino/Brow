import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: OverlayState
    let bandWidth: CGFloat
    let bandHeight: CGFloat
    let drawerSize: CGSize
    let roundedBand: Bool
    /// Horizontal distance from the screen's center to the notch's center.
    let notchOffset: CGFloat
    /// Zero leaves the screen's top corners alone.
    let cornerRadius: CGFloat

    /// Around the notch, the drawer is at least as wide as the band so the two read as one shape.
    private var drawerWidth: CGFloat {
        roundedBand ? max(drawerSize.width, bandWidth) : drawerSize.width
    }

    var body: some View {
        // Square off the band's corners while the drawer hangs from it, so there's no step at the seam.
        let bandRadius: CGFloat = roundedBand && !state.drawerOpen ? 12 : 0

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: bandRadius, bottomTrailing: bandRadius))
                    .fill(.black)
                    .frame(width: bandWidth, height: bandHeight)
                    .zIndex(1) // keep the drawer sliding out from underneath the band

                if state.drawerOpen {
                    DrawerView()
                        .frame(width: drawerWidth, height: drawerSize.height)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 20, bottomTrailing: 20))
                                .fill(.black)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .offset(x: notchOffset)
            .opacity(state.bandHidden ? 0 : 1)
            .animation(.easeInOut(duration: 0.15), value: state.bandHidden)

            if cornerRadius > 0 {
                HStack(spacing: 0) {
                    ScreenCorner(radius: cornerRadius, mirrored: false)
                    Spacer(minLength: 0)
                    ScreenCorner(radius: cornerRadius, mirrored: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// A black square with a quarter circle cut out, so the screen's top-left corner
/// (or top-right, when mirrored) reads as rounded.
struct ScreenCorner: View {
    let radius: CGFloat
    let mirrored: Bool

    var body: some View {
        // The sliver between the corner point and a quarter-circle arc of the given radius.
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addArc(tangent1End: .zero, tangent2End: CGPoint(x: 0, y: radius), radius: radius)
            path.closeSubpath()
        }
        .fill(.black)
        .frame(width: radius, height: radius)
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }
}
