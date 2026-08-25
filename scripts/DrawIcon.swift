// Draw the UsageDashboard app icon (1024x1024 PNG) via CoreGraphics.
// Usage: swift scripts/DrawIcon.swift [output.png]
import CoreGraphics
import ImageIO
import Foundation

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no context") }

// Background: full-bleed square gradient (macOS applies the rounded mask/shadow).
let colors = [
    CGColor(red: 0.30, green: 0.27, blue: 0.95, alpha: 1),  // indigo
    CGColor(red: 0.60, green: 0.44, blue: 0.97, alpha: 1),  // violet
] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

// Usage bar chart: rounded-top bars of increasing height
let baseline: CGFloat = 700
let barWidth: CGFloat = 104
let gap: CGFloat = 48
let heights: [CGFloat] = [170, 250, 330, 420]
let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
let startX = (CGFloat(size) - totalWidth) / 2
let barColor = CGColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 0.96)
let r = barWidth / 2

for (i, h) in heights.enumerated() {
    let rect = CGRect(x: startX + CGFloat(i) * (barWidth + gap), y: baseline - h, width: barWidth, height: h)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r))
    p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.minY), radius: r)
    p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
    p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.minY + r), radius: r)
    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    p.closeSubpath()
    ctx.setFillColor(barColor)
    ctx.addPath(p)
    ctx.fillPath()
}

guard let image = ctx.makeImage() else { fatalError("no image") }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/UsageDashboard-icon.png"
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else { fatalError("no dest") }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
