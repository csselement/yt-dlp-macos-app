import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = root.appendingPathComponent("AppResources", isDirectory: true)
let iconset = outputDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconImage {
    let name: String
    let points: CGFloat
    let scale: CGFloat

    var pixels: CGFloat { points * scale }
}

let images = [
    IconImage(name: "icon_16x16.png", points: 16, scale: 1),
    IconImage(name: "icon_16x16@2x.png", points: 16, scale: 2),
    IconImage(name: "icon_32x32.png", points: 32, scale: 1),
    IconImage(name: "icon_32x32@2x.png", points: 32, scale: 2),
    IconImage(name: "icon_128x128.png", points: 128, scale: 1),
    IconImage(name: "icon_128x128@2x.png", points: 128, scale: 2),
    IconImage(name: "icon_256x256.png", points: 256, scale: 1),
    IconImage(name: "icon_256x256@2x.png", points: 256, scale: 2),
    IconImage(name: "icon_512x512.png", points: 512, scale: 1),
    IconImage(name: "icon_512x512@2x.png", points: 512, scale: 2)
]

for image in images {
    let size = NSSize(width: image.pixels, height: image.pixels)
    let icon = NSImage(size: size)
    icon.lockFocus()
    drawIcon(in: NSRect(origin: .zero, size: size))
    icon.unlockFocus()

    guard
        let tiff = icon.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGeneration", code: 1)
    }

    try png.write(to: iconset.appendingPathComponent(image.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconset.path,
    "-o", outputDir.appendingPathComponent("AppIcon.icns").path
]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}

func drawIcon(in rect: NSRect) {
    let scale = rect.width / 1024
    let cornerRadius = 220 * scale
    let bounds = rect.insetBy(dx: 32 * scale, dy: 32 * scale)
    let background = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

    NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.13, alpha: 1).setFill()
    background.fill()

    let inner = bounds.insetBy(dx: 62 * scale, dy: 62 * scale)
    let innerPath = NSBezierPath(roundedRect: inner, xRadius: 164 * scale, yRadius: 164 * scale)
    NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.22, alpha: 1).setFill()
    innerPath.fill()

    drawFilmStrip(in: NSRect(x: 210 * scale, y: 220 * scale, width: 604 * scale, height: 408 * scale), scale: scale)
    drawAudioBars(in: NSRect(x: 284 * scale, y: 250 * scale, width: 456 * scale, height: 118 * scale), scale: scale)
    drawDownloadArrow(in: NSRect(x: 330 * scale, y: 388 * scale, width: 364 * scale, height: 378 * scale), scale: scale)
}

func drawFilmStrip(in rect: NSRect, scale: CGFloat) {
    let radius = 44 * scale
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.91, green: 0.95, blue: 0.96, alpha: 1).setFill()
    path.fill()

    NSColor(calibratedRed: 0.09, green: 0.14, blue: 0.17, alpha: 1).setFill()
    let holes = 5
    let holeWidth = 46 * scale
    let holeHeight = 54 * scale
    let gap = (rect.width - CGFloat(holes) * holeWidth) / CGFloat(holes + 1)

    for index in 0..<holes {
        let x = rect.minX + gap + CGFloat(index) * (holeWidth + gap)
        NSBezierPath(roundedRect: NSRect(x: x, y: rect.maxY - 78 * scale, width: holeWidth, height: holeHeight), xRadius: 10 * scale, yRadius: 10 * scale).fill()
        NSBezierPath(roundedRect: NSRect(x: x, y: rect.minY + 24 * scale, width: holeWidth, height: holeHeight), xRadius: 10 * scale, yRadius: 10 * scale).fill()
    }

    let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 118 * scale, dy: 90 * scale), xRadius: 28 * scale, yRadius: 28 * scale)
    NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.49, alpha: 1).setFill()
    frame.fill()
}

func drawDownloadArrow(in rect: NSRect, scale: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.midX - 64 * scale, y: rect.maxY))
    path.line(to: NSPoint(x: rect.midX + 64 * scale, y: rect.maxY))
    path.line(to: NSPoint(x: rect.midX + 64 * scale, y: rect.minY + 156 * scale))
    path.line(to: NSPoint(x: rect.maxX, y: rect.minY + 156 * scale))
    path.line(to: NSPoint(x: rect.midX, y: rect.minY))
    path.line(to: NSPoint(x: rect.minX, y: rect.minY + 156 * scale))
    path.line(to: NSPoint(x: rect.midX - 64 * scale, y: rect.minY + 156 * scale))
    path.close()

    NSColor(calibratedRed: 0.13, green: 0.63, blue: 0.74, alpha: 1).setFill()
    path.fill()

    let tray = NSBezierPath(roundedRect: NSRect(x: rect.minX + 24 * scale, y: rect.minY - 72 * scale, width: rect.width - 48 * scale, height: 72 * scale), xRadius: 22 * scale, yRadius: 22 * scale)
    tray.fill()
}

func drawAudioBars(in rect: NSRect, scale: CGFloat) {
    NSColor(calibratedRed: 0.97, green: 0.73, blue: 0.28, alpha: 1).setFill()
    let heights: [CGFloat] = [38, 78, 48, 106, 64, 92, 42]
    let barWidth = 32 * scale
    let gap = (rect.width - CGFloat(heights.count) * barWidth) / CGFloat(heights.count - 1)

    for (index, height) in heights.enumerated() {
        let x = rect.minX + CGFloat(index) * (barWidth + gap)
        let y = rect.midY - height * scale / 2
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: height * scale), xRadius: 12 * scale, yRadius: 12 * scale).fill()
    }
}
