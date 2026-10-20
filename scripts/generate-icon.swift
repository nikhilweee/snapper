import AppKit

// Vector source for the application icon. Run from any directory with:
// swift /path/to/snapper/scripts/generate-icon.swift
let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = project.appendingPathComponent("Resources")
let iconset = project.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon() {
    let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 25
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(red: 0.25, green: 0.24, blue: 0.75, alpha: 1).setFill()
    background.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(starting: NSColor(red: 0.24, green: 0.24, blue: 0.72, alpha: 1),
                              ending: NSColor(red: 0.53, green: 0.46, blue: 0.95, alpha: 1))!
    gradient.draw(in: background, angle: 90)
    NSColor.white.withAlphaComponent(0.20).setStroke()
    background.lineWidth = 3
    background.stroke()

    // A pair of columns, with the right column split into two snap zones.
    let frame = NSBezierPath(roundedRect: NSRect(x: 216, y: 228, width: 592, height: 568), xRadius: 44, yRadius: 44)
    NSColor.white.withAlphaComponent(0.36).setStroke()
    frame.lineWidth = 12
    frame.stroke()

    NSGraphicsContext.saveGraphicsState()
    let paneShadow = NSShadow()
    paneShadow.shadowColor = NSColor(red: 0.10, green: 0.08, blue: 0.40, alpha: 0.20)
    paneShadow.shadowBlurRadius = 16
    paneShadow.shadowOffset = NSSize(width: 0, height: -8)
    paneShadow.set()
    NSColor.white.withAlphaComponent(0.94).setFill()
    NSBezierPath(roundedRect: NSRect(x: 252, y: 264, width: 226, height: 496), xRadius: 22, yRadius: 22).fill()
    NSColor.white.withAlphaComponent(0.65).setFill()
    NSBezierPath(roundedRect: NSRect(x: 514, y: 530, width: 258, height: 230), xRadius: 22, yRadius: 22).fill()
    NSGraphicsContext.restoreGraphicsState()

    let activePane = NSBezierPath(roundedRect: NSRect(x: 514, y: 264, width: 258, height: 230), xRadius: 22, yRadius: 22)
    NSGradient(starting: NSColor(red: 0.20, green: 0.81, blue: 0.91, alpha: 1),
               ending: NSColor(red: 0.55, green: 0.96, blue: 0.97, alpha: 1))!.draw(in: activePane, angle: 90)
    NSColor.white.withAlphaComponent(0.90).setStroke()
    activePane.lineWidth = 5
    activePane.stroke()
}

func png(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SnapperIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create icon bitmap."])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SnapperIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot encode icon PNG."])
    }
    return data
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try png(size: points * scale).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"), options: .atomic)
    }
}
try png(size: 1024).write(to: project.appendingPathComponent(".build/AppIcon.png"), options: .atomic)
let converter = Process()
converter.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
converter.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try converter.run()
converter.waitUntilExit()
guard converter.terminationStatus == 0 else { exit(converter.terminationStatus) }
print("Generated Resources/AppIcon.icns and .build/AppIcon.png")
