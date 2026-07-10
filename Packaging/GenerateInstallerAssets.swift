import AppKit

private struct AssetError: Error, CustomStringConvertible {
    let description: String
}

guard CommandLine.arguments.count == 3 else {
    throw AssetError(description: "Usage: GenerateInstallerAssets.swift <iconset-dir> <background-png>")
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1])
let backgroundURL = URL(fileURLWithPath: CommandLine.arguments[2])
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: backgroundURL.deletingLastPathComponent(), withIntermediateDirectories: true)

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw AssetError(description: "Could not render PNG for \(url.path)")
    }

    try pngData.write(to: url)
}

private func drawRoundedRect(
    _ rect: NSRect,
    radius: CGFloat,
    fill: NSColor,
    stroke: NSColor? = nil,
    lineWidth: CGFloat = 1
) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()

    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

private func makeIcon(size: Int, accentColor: NSColor) -> NSImage {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()

    let tile = NSRect(x: side * 0.06, y: side * 0.06, width: side * 0.88, height: side * 0.88)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.20, alpha: 1)
    ])
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: side * 0.22, yRadius: side * 0.22)
    gradient?.draw(in: tilePath, angle: -35)

    NSColor(calibratedWhite: 1, alpha: 0.18).setStroke()
    tilePath.lineWidth = max(1, side * 0.015)
    tilePath.stroke()

    let chainStroke = NSColor(calibratedWhite: 1, alpha: 0.94)
    chainStroke.setStroke()
    let lineWidth = side * 0.055

    for rect in [
        NSRect(x: side * 0.22, y: side * 0.47, width: side * 0.33, height: side * 0.18),
        NSRect(x: side * 0.45, y: side * 0.35, width: side * 0.33, height: side * 0.18)
    ] {
        let link = NSBezierPath(roundedRect: rect, xRadius: side * 0.09, yRadius: side * 0.09)
        link.lineWidth = lineWidth
        link.stroke()
    }

    let slash = NSBezierPath()
    slash.move(to: NSPoint(x: side * 0.34, y: side * 0.31))
    slash.line(to: NSPoint(x: side * 0.70, y: side * 0.70))
    slash.lineWidth = side * 0.065
    slash.lineCapStyle = .round
    accentColor.setStroke()
    slash.stroke()

    let badgeRect = NSRect(x: side * 0.63, y: side * 0.16, width: side * 0.22, height: side * 0.22)
    accentColor.setFill()
    NSBezierPath(ovalIn: badgeRect).fill()

    NSColor.white.setStroke()
    let minus = NSBezierPath()
    minus.move(to: NSPoint(x: badgeRect.minX + badgeRect.width * 0.25, y: badgeRect.midY))
    minus.line(to: NSPoint(x: badgeRect.maxX - badgeRect.width * 0.25, y: badgeRect.midY))
    minus.lineWidth = side * 0.032
    minus.lineCapStyle = .round
    minus.stroke()

    image.unlockFocus()
    return image
}

private func makeBackground() -> NSImage {
    let size = NSSize(width: 720, height: 440)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.985, green: 0.988, blue: 0.992, alpha: 1),
        NSColor(calibratedRed: 0.940, green: 0.950, blue: 0.960, alpha: 1)
    ])?.draw(in: bounds, angle: -90)

    drawRoundedRect(
        NSRect(x: 34, y: 34, width: 652, height: 372),
        radius: 28,
        fill: NSColor(calibratedWhite: 1, alpha: 0.64),
        stroke: NSColor(calibratedWhite: 0, alpha: 0.08),
        lineWidth: 1
    )

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1)
    ]
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.43, alpha: 1)
    ]

    let title = "Untracker" as NSString
    title.draw(
        at: NSPoint(x: (size.width - title.size(withAttributes: titleAttributes).width) / 2, y: 342),
        withAttributes: titleAttributes
    )

    let subtitle = "Drag Untracker to Applications" as NSString
    subtitle.draw(
        at: NSPoint(x: (size.width - subtitle.size(withAttributes: subtitleAttributes).width) / 2, y: 318),
        withAttributes: subtitleAttributes
    )

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 315, y: 210))
    arrow.line(to: NSPoint(x: 405, y: 210))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    NSColor(calibratedRed: 0.30, green: 0.34, blue: 0.38, alpha: 0.52).setStroke()
    arrow.stroke()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: NSPoint(x: 405, y: 210))
    arrowHead.line(to: NSPoint(x: 386, y: 226))
    arrowHead.move(to: NSPoint(x: 405, y: 210))
    arrowHead.line(to: NSPoint(x: 386, y: 194))
    arrowHead.lineWidth = 5
    arrowHead.lineCapStyle = .round
    arrowHead.stroke()

    image.unlockFocus()
    return image
}

let iconSpecs: [(file: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in iconSpecs {
    try writePNG(
        makeIcon(size: spec.pixels, accentColor: .systemGreen),
        to: iconsetURL.appendingPathComponent(spec.file)
    )
}

try writePNG(makeBackground(), to: backgroundURL)
