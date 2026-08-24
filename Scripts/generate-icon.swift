// Generates Resources/AppIcon.icns: a green circle with the same
// checkmark.circle.fill glyph the bar uses for the "all up" state, at every
// size macOS expects in an .icns. Run with:
//   swift Scripts/generate-icon.swift
// Requires iconutil (part of Xcode command line tools), invoked at the end.

import AppKit
import Foundation

let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x")
]

let rootDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconsetDir = rootDir.appendingPathComponent("Resources/AppIcon.iconset")
let icnsPath = rootDir.appendingPathComponent("Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (size, name) in sizes {
    let canvas = NSImage(size: NSSize(width: size, height: size))
    canvas.lockFocus()

    NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.35, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()

    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.5, weight: .bold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let origin = NSPoint(
            x: (CGFloat(size) - symbol.size.width) / 2,
            y: (CGFloat(size) - symbol.size.height) / 2
        )
        symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    canvas.unlockFocus()

    guard let tiff = canvas.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("could not render \(name)")
    }
    try png.write(to: iconsetDir.appendingPathComponent("\(name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetDir)

print(process.terminationStatus == 0 ? "Wrote \(icnsPath.path)" : "iconutil failed")
