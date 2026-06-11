import Cocoa

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let baseSize: CGFloat = 1024
let outputDir = CommandLine.arguments[1]

func drawIcon(size: CGFloat, scale: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    defer { img.unlockFocus() }

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let s = size / baseSize

    // Background gradient
    let colors = [NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1).cgColor,
                  NSColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1).cgColor]
    let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1])!
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    bgPath.addClip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Outer border (subtle glow)
    NSColor.white.withAlphaComponent(0.15).setStroke()
    bgPath.lineWidth = s * 4
    bgPath.stroke()

    // Inner shield shape - a subtle lighter overlay
    let insetRect = rect.insetBy(dx: size * 0.08, dy: size * 0.08)
    let shieldPath = NSBezierPath(roundedRect: insetRect, xRadius: size * 0.18, yRadius: size * 0.18)
    NSColor.white.withAlphaComponent(0.08).setFill()
    shieldPath.fill()

    // CPU die shape (center square with rounded corners)
    let dieSize = size * 0.38
    let dieRect = CGRect(x: (size - dieSize) / 2, y: (size - dieSize) / 2, width: dieSize, height: dieSize)
    let diePath = NSBezierPath(roundedRect: dieRect, xRadius: dieSize * 0.15, yRadius: dieSize * 0.15)
    NSColor.white.withAlphaComponent(0.9).setFill()
    diePath.fill()

    // Inner die detail - darker square
    let innerSize = dieSize * 0.6
    let innerRect = CGRect(x: (size - innerSize) / 2, y: (size - innerSize) / 2, width: innerSize, height: innerSize)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: innerSize * 0.12, yRadius: innerSize * 0.12)
    NSColor(red: 0.15, green: 0.3, blue: 0.7, alpha: 1).setFill()
    innerPath.fill()

    // Central dot
    let dotSize = innerSize * 0.25
    let dotRect = CGRect(x: (size - dotSize) / 2, y: (size - dotSize) / 2, width: dotSize, height: dotSize)
    NSColor.white.withAlphaComponent(0.6).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    // Pins around the die (small circles on each edge)
    let pinRadius = dieSize * 0.06
    let pinColor = NSColor.white.withAlphaComponent(0.5)
    pinColor.setFill()
    for (dx, dy) in [(-0.55, 0.0), (0.55, 0.0), (0.0, -0.55), (0.0, 0.55)] {
        let cx = size / 2 + dieSize * CGFloat(dx)
        let cy = size / 2 + dieSize * CGFloat(dy)
        let pinRect = CGRect(x: cx - pinRadius, y: cy - pinRadius, width: pinRadius * 2, height: pinRadius * 2)
        NSBezierPath(ovalIn: pinRect).fill()
    }

    // Activity waveform (heartbeat line) at the bottom
    let waveY = size * 0.78
    let waveScale = size * 0.35
    NSColor.white.withAlphaComponent(0.7).setStroke()
    let wavePath = NSBezierPath()
    wavePath.lineWidth = s * 4
    wavePath.lineCapStyle = .round
    wavePath.move(to: CGPoint(x: size * 0.15, y: waveY))
    wavePath.line(to: CGPoint(x: size * 0.3, y: waveY))
    wavePath.line(to: CGPoint(x: size * 0.38, y: waveY + waveScale * 0.25))
    wavePath.line(to: CGPoint(x: size * 0.46, y: waveY - waveScale * 0.25))
    wavePath.line(to: CGPoint(x: size * 0.54, y: waveY + waveScale * 0.25))
    wavePath.line(to: CGPoint(x: size * 0.62, y: waveY - waveScale * 0.25))
    wavePath.line(to: CGPoint(x: size * 0.7, y: waveY))
    wavePath.line(to: CGPoint(x: size * 0.85, y: waveY))
    wavePath.stroke()

    // Small "AG" text at bottom of die
    let text = "AG" as NSString
    let font = NSFont.boldSystemFont(ofSize: size * 0.1)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.6)
    ]
    let textSize = text.size(withAttributes: attrs)
    let textRect = CGRect(x: (size - textSize.width) / 2, y: size * 0.06, width: textSize.width, height: textSize.height)
    text.draw(in: textRect, withAttributes: attrs)

    return img
}

func savePNG(_ image: NSImage, at path: String) {
    let w = Int(image.size.width)
    let h = Int(image.size.height)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: w,
        pixelsHigh: h,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// Generate .iconset folder
let iconSetDir = outputDir + "/AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconSetDir, withIntermediateDirectories: true)

for size in sizes {
    let scaleSizes: [(Int, String)] = size >= 512
        ? [(size, ""), (size * 2, "@2x")]
        : [(size, "")]
    for (px, suffix) in scaleSizes {
        let img = drawIcon(size: CGFloat(px), scale: CGFloat(px) / baseSize)
        let filename = "icon_\(size)\(suffix).png"
        savePNG(img, at: iconSetDir + "/" + filename)
    }
}

print("Icon set generated at \(iconSetDir)")
