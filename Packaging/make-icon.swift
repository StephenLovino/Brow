// Draws Brow's 1024×1024 app icon: a soft squircle with a black notch drawer showing the time.
// Usage: swift Packaging/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
    // macOS icon grid: an 824pt rounded square centered in the 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    NSColor.white.setFill()
    tilePath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [
        NSColor(red: 1.00, green: 0.92, blue: 0.55, alpha: 1),
        NSColor(red: 1.00, green: 0.75, blue: 0.00, alpha: 1),
    ])?.draw(in: tile, angle: 90)

    // The notch drawer hanging from the top edge of the tile.
    let drawer = CGRect(x: 232, y: 100, width: 560, height: 330)
    NSColor(white: 0.06, alpha: 1).setFill()
    NSBezierPath(roundedRect: drawer.insetBy(dx: 0, dy: -120).offsetBy(dx: 0, dy: -0), xRadius: 120, yRadius: 120).fill()
    NSBezierPath(rect: CGRect(x: drawer.minX, y: drawer.minY, width: drawer.width, height: 120)).fill()

    let time = NSAttributedString(string: "9:41", attributes: [
        .font: NSFont.systemFont(ofSize: 150, weight: .heavy).rounded,
        .foregroundColor: NSColor.white,
    ])
    let timeSize = time.size()
    time.draw(at: CGPoint(x: drawer.midX - timeSize.width / 2, y: drawer.minY + 140))

    // A small camera dot, so the drawer still reads as the notch.
    NSColor(white: 0.22, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: drawer.midX - 18, y: drawer.minY + 52, width: 36, height: 36)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    return true
}

extension NSFont {
    var rounded: NSFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

guard let tiff = image.tiffRepresentation,
      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
else { fatalError("could not render icon") }
try png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
