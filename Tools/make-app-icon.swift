// Draws EyeBreak's app icon: two lines on linen, the eye line (leaf green) catching once
// and the water line (rain blue) running straight — the rhythm line the app draws all day.
// Solid colours on the macOS icon grid (an 824-pt squircle centred in 1024) with one soft
// shadow, as on Apple's template.
//
//   xcrun swiftc -o /tmp/make-app-icon Tools/make-app-icon.swift
//   /tmp/make-app-icon Sources/Eyebreak/Resources/AppIcon.png
//
// build.sh turns AppIcon.png into AppIcon.icns whenever the PNG is newer.

import AppKit
import SwiftUI

func rgb(_ v: UInt32) -> Color {
    Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

let linen = rgb(0xFAF9F4)
let leaf = rgb(0x2C7A43)
let rain = rgb(0x1C7DB4)

struct AppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(linen)
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)

            Canvas { context, _ in
                // Eyes: straight, a catch, eased back to the line
                var eyes = Path()
                eyes.move(to: CGPoint(x: 176, y: 352))
                eyes.addLine(to: CGPoint(x: 372, y: 352))
                eyes.addLine(to: CGPoint(x: 400, y: 436))
                eyes.addCurve(to: CGPoint(x: 548, y: 352),
                              control1: CGPoint(x: 432, y: 436), control2: CGPoint(x: 486, y: 352))
                eyes.addLine(to: CGPoint(x: 616, y: 352))
                context.stroke(eyes, with: .color(leaf), style: StrokeStyle(lineWidth: 44, lineCap: .round, lineJoin: .round))
                context.fill(Path(ellipseIn: CGRect(x: 576, y: 312, width: 80, height: 80)), with: .color(leaf))

                // Water: straight all the way
                var water = Path()
                water.move(to: CGPoint(x: 176, y: 520))
                water.addLine(to: CGPoint(x: 616, y: 520))
                context.stroke(water, with: .color(rain), style: StrokeStyle(lineWidth: 44, lineCap: .round))
                context.fill(Path(ellipseIn: CGRect(x: 576, y: 480, width: 80, height: 80)), with: .color(rain))
            }
            .frame(width: 824, height: 824)
        }
        .frame(width: 1024, height: 1024)
    }
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: AppIcon())
    renderer.scale = 1
    guard let tiff = renderer.nsImage?.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        fatalError("Couldn't render the icon")
    }
    try! png.write(to: URL(fileURLWithPath: output))
}
