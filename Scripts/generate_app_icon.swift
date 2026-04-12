import AppKit
import ImageIO
import Foundation

struct IconSpec {
    let size: Int
    let filename: String
}

let specs: [IconSpec] = [
    .init(size: 16, filename: "icon_16x16.png"),
    .init(size: 32, filename: "icon_16x16@2x.png"),
    .init(size: 32, filename: "icon_32x32.png"),
    .init(size: 64, filename: "icon_32x32@2x.png"),
    .init(size: 128, filename: "icon_128x128.png"),
    .init(size: 256, filename: "icon_128x128@2x.png"),
    .init(size: 256, filename: "icon_256x256.png"),
    .init(size: 512, filename: "icon_256x256@2x.png"),
    .init(size: 512, filename: "icon_512x512.png"),
    .init(size: 1024, filename: "icon_512x512@2x.png")
]

let outputDirectory: URL
if CommandLine.arguments.count > 1 {
    outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
} else {
    outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

let referenceImageURL = URL(fileURLWithPath: "/Users/wxc/Programing/3.png")
let referenceCGImage: CGImage? = {
    guard let source = CGImageSourceCreateWithURL(referenceImageURL as CFURL, nil) else {
        return nil
    }

    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
    }

    let inset = min(image.width, image.height) / 28
    let cropRect = CGRect(
        x: inset,
        y: inset,
        width: image.width - inset * 2,
        height: image.height - inset * 2
    )

    return image.cropping(to: cropRect.integral) ?? image
}()

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let image = drawIcon(size: spec.size)
    let destination = outputDirectory.appendingPathComponent(spec.filename)
    try save(image: image, to: destination)
    print("Wrote \(destination.path)")
}

func drawIcon(size: Int) -> NSImage {
    if let referenceCGImage {
        return drawReferenceIcon(from: referenceCGImage, size: size)
    }

    return drawFallbackIcon(size: size)
}

func drawReferenceIcon(from referenceCGImage: CGImage, size: Int) -> NSImage {
    let canvas = CGSize(width: size, height: size)
    let image = NSImage(size: canvas)
    guard
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: representation)?.cgContext
    else {
        return image
    }

    let rect = CGRect(origin: .zero, size: canvas)
    let inset = CGFloat(size) * 0.045
    let iconRect = rect.insetBy(dx: inset, dy: inset)
    let corner = CGFloat(size) * 0.205
    let shadowBlur = CGFloat(size) * 0.055

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let shadowPath = NSBezierPath(roundedRect: iconRect, xRadius: corner, yRadius: corner).cgPath
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -CGFloat(size) * 0.02), blur: shadowBlur, color: NSColor(calibratedWhite: 0, alpha: 0.18).cgColor)
    context.addPath(shadowPath)
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shadowPath)
    context.clip()

    let destinationRect = iconRect.insetBy(dx: CGFloat(size) * 0.01, dy: CGFloat(size) * 0.01)
    context.draw(referenceCGImage, in: destinationRect)

    context.restoreGState()

    context.saveGState()
    context.addPath(shadowPath)
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.55).cgColor)
    context.setLineWidth(max(1, CGFloat(size) * 0.006))
    context.strokePath()
    context.restoreGState()

    image.addRepresentation(representation)
    return image
}

func drawFallbackIcon(size: Int) -> NSImage {
    let canvas = CGSize(width: size, height: size)
    let image = NSImage(size: canvas)
    guard
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: representation)?.cgContext
    else {
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let rect = CGRect(origin: .zero, size: canvas)
    let corner = CGFloat(size) * 0.225
    let shell = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner).cgPath
    context.saveGState()
    context.addPath(shell)
    context.clip()

    let warmTop = NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.83, alpha: 1).cgColor
    let warmBottom = NSColor(calibratedRed: 0.96, green: 0.85, blue: 0.34, alpha: 1).cgColor
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [warmTop, warmBottom] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: rect.maxX, y: 0), options: [])

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.42).cgColor,
            NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: rect.midX * 0.84, y: rect.maxY * 0.76),
        startRadius: 0,
        endCenter: CGPoint(x: rect.midX * 0.84, y: rect.maxY * 0.76),
        endRadius: CGFloat(size) * 0.58,
        options: []
    )

    drawBackdropLines(in: context, size: size)
    drawSelectionFrame(in: context, size: size)
    drawHighlightSweep(in: context, size: size)

    context.restoreGState()
    image.addRepresentation(representation)
    return image
}

func drawBackdropLines(in context: CGContext, size: Int) {
    let size = CGFloat(size)
    let left = size * 0.21
    let width = size * 0.52
    let lineHeight = max(4, size * 0.028)
    let gap = size * 0.065
    let top = size * 0.65

    for index in 0 ..< 3 {
        let alpha = index == 1 ? 0.24 : 0.16
        let y = top - CGFloat(index) * gap
        let lineRect = CGRect(x: left, y: y, width: width - CGFloat(index) * size * 0.07, height: lineHeight)
        let path = NSBezierPath(roundedRect: lineRect, xRadius: lineHeight / 2, yRadius: lineHeight / 2).cgPath
        context.setFillColor(NSColor(calibratedWhite: 0.14, alpha: alpha).cgColor)
        context.addPath(path)
        context.fillPath()
    }
}

func drawSelectionFrame(in context: CGContext, size: Int) {
    let size = CGFloat(size)
    let stroke = max(2, size * 0.03)
    let insetX = size * 0.18
    let insetY = size * 0.2
    let frameWidth = size * 0.64
    let frameHeight = size * 0.48
    let cornerLength = size * 0.12
    let color = NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 0.92).cgColor

    context.setStrokeColor(color)
    context.setLineWidth(stroke)
    context.setLineCap(.round)

    let minX = insetX
    let maxX = insetX + frameWidth
    let minY = insetY
    let maxY = insetY + frameHeight

    let segments: [(CGPoint, CGPoint)] = [
        (.init(x: minX, y: maxY - cornerLength), .init(x: minX, y: maxY)),
        (.init(x: minX, y: maxY), .init(x: minX + cornerLength, y: maxY)),
        (.init(x: maxX - cornerLength, y: maxY), .init(x: maxX, y: maxY)),
        (.init(x: maxX, y: maxY - cornerLength), .init(x: maxX, y: maxY)),
        (.init(x: minX, y: minY), .init(x: minX + cornerLength, y: minY)),
        (.init(x: minX, y: minY), .init(x: minX, y: minY + cornerLength)),
        (.init(x: maxX - cornerLength, y: minY), .init(x: maxX, y: minY)),
        (.init(x: maxX, y: minY), .init(x: maxX, y: minY + cornerLength))
    ]

    for segment in segments {
        context.beginPath()
        context.move(to: segment.0)
        context.addLine(to: segment.1)
        context.strokePath()
    }
}

func drawHighlightSweep(in context: CGContext, size: Int) {
    let size = CGFloat(size)
    let rect = CGRect(
        x: size * 0.28,
        y: size * 0.42,
        width: size * 0.44,
        height: size * 0.16
    )

    let highlight = NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.1, alpha: 0.95).cgColor
    let trailing = NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.06, alpha: 0.72).cgColor
    let edgeGlow = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.88).cgColor

    context.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.03, color: NSColor(calibratedRed: 0.58, green: 0.39, blue: 0.01, alpha: 0.20).cgColor)
    context.setFillColor(trailing)
    context.fill(rect)
    context.setShadow(offset: .zero, blur: 0, color: nil)

    let litRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.72, height: rect.height)
    context.setFillColor(highlight)
    context.fill(litRect)

    let edgeRect = CGRect(x: litRect.maxX - max(2, size * 0.015), y: rect.minY, width: max(2, size * 0.018), height: rect.height)
    context.setFillColor(edgeGlow)
    context.fill(edgeRect)
}

func save(image: NSImage, to destination: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let representation = NSBitmapImageRep(data: tiff),
        let png = representation.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "FocusShotIcon", code: 1)
    }

    try png.write(to: destination)
}
