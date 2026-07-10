import AppKit

@MainActor
enum StatusIconRenderer {
    private static let designSize: CGFloat = 24

    static func image(isOperational: Bool, size: CGFloat) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            context.saveGState()
            context.scaleBy(
                x: bounds.width / designSize,
                y: bounds.height / designSize
            )
            drawMark(isOperational: isOperational)
            context.restoreGState()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Untracker"
        return image
    }

    private static func drawMark(isOperational: Bool) {
        let markColor = NSColor.labelColor.withAlphaComponent(0.92)
        markColor.setStroke()

        let linkRects = [
            NSRect(x: 0.8, y: 10.64, width: 12.96, height: 7.07),
            NSRect(x: 9.84, y: 7.93, width: 12.96, height: 7.07)
        ]
        for rect in linkRects {
            let link = NSBezierPath(roundedRect: rect, xRadius: 3.54, yRadius: 3.54)
            link.lineWidth = 2.16
            link.stroke()
        }

        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: 5.51, y: 4.35))
        slash.line(to: NSPoint(x: 19.66, y: 19.67))
        slash.lineWidth = 2.55
        slash.lineCapStyle = .round
        (isOperational ? NSColor.systemGreen : NSColor.systemRed).setStroke()
        slash.stroke()

        drawStatusBadge(isOperational: isOperational)
    }

    private static func drawStatusBadge(isOperational: Bool) {
        let badgeRect = NSRect(x: 13.5, y: 0.2, width: 10.3, height: 10.3)
        let accentColor: NSColor = isOperational ? .systemGreen : .systemRed
        accentColor.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        NSColor.white.setStroke()
        if isOperational {
            let checkmark = NSBezierPath()
            checkmark.move(to: NSPoint(x: 16.1, y: 5.1))
            checkmark.line(to: NSPoint(x: 18.1, y: 3.2))
            checkmark.line(to: NSPoint(x: 21.6, y: 7.3))
            checkmark.lineWidth = 1.7
            checkmark.lineCapStyle = .round
            checkmark.lineJoinStyle = .round
            checkmark.stroke()
        } else {
            for x in [16.8, 19.6] {
                let pauseBar = NSBezierPath()
                pauseBar.move(to: NSPoint(x: x, y: 3.1))
                pauseBar.line(to: NSPoint(x: x, y: 7.5))
                pauseBar.lineWidth = 1.7
                pauseBar.lineCapStyle = .round
                pauseBar.stroke()
            }
        }
    }
}
