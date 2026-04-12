import AppKit
import AVFoundation
import Foundation

enum VideoExportError: LocalizedError {
    case missingImage
    case invalidRegion
    case cancelled
    case writerSetupFailed
    case bufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .missingImage:
            return "没有可导出的截图。"
        case .invalidRegion:
            return "动画区域无效，无法导出。"
        case .cancelled:
            return "已取消导出。"
        case .writerSetupFailed:
            return "视频导出器初始化失败。"
        case .bufferCreationFailed:
            return "视频帧生成失败。"
        }
    }
}

struct VideoExportService {
    func exportMP4(
        image: NSImage?,
        animationRegions: [AnimationRegion],
        duration: Double,
        opacity: Double,
        strokeWidth: Double,
        independentAnimationEasing: Bool,
        easingCurve: AnimationEasingCurve,
        blendMode: HighlightBlendMode,
        fillColorHex: String,
        strokeColorHex: String
    ) async throws -> URL {
        guard let image else {
            throw VideoExportError.missingImage
        }

        guard !animationRegions.isEmpty else {
            throw VideoExportError.invalidRegion
        }

        guard let targetURL = await MainActor.run(body: { chooseExportURL() }) else {
            throw VideoExportError.cancelled
        }

        let pixelSize = videoSize(for: image)
        let regionRects = animationRegions.map {
            CGRect(
                x: CGFloat(pixelSize.width) * $0.normalizedRect.minX,
                y: CGFloat(pixelSize.height) * (1 - $0.normalizedRect.minY - $0.normalizedRect.height),
                width: CGFloat(pixelSize.width) * $0.normalizedRect.width,
                height: CGFloat(pixelSize.height) * $0.normalizedRect.height
            ).integral
        }

        guard regionRects.allSatisfy({ $0.width > 0 && $0.height > 0 }) else {
            throw VideoExportError.invalidRegion
        }

        try? FileManager.default.removeItem(at: targetURL)

        let writer = try AVAssetWriter(outputURL: targetURL, fileType: .mp4)
        let bitrate = max(60_000_000, Int(pixelSize.width * pixelSize.height * 24))
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelSize.width,
            AVVideoHeightKey: pixelSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 1,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false
        input.performsMultiPassEncodingIfSupported = true

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: pixelSize.width,
            kCVPixelBufferHeightKey as String: pixelSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else {
            throw VideoExportError.writerSetupFailed
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? VideoExportError.writerSetupFailed
        }
        writer.startSession(atSourceTime: .zero)

        let fps = 60
        let leadInFrames = 3
        let animationFrameCount = max(1, Int(ceil(duration * Double(fps))))
        let frameCount = animationFrameCount + leadInFrames
        let frameDuration = CMTime(value: 1, timescale: Int32(fps))

        let renderer = AnimationFrameRenderer(
            image: image,
            canvasSize: pixelSize,
            highlightRects: regionRects,
            opacity: opacity,
            strokeWidth: strokeWidth,
            independentAnimationEasing: independentAnimationEasing,
            easingCurve: easingCurve,
            blendMode: blendMode,
            fillColor: NSColor(hex: fillColorHex) ?? .systemYellow,
            strokeColor: NSColor(hex: strokeColorHex) ?? .systemOrange
        )

        for index in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }

            let totalProgress: CGFloat
            if index < leadInFrames {
                totalProgress = 0
            } else {
                totalProgress = CGFloat(index - leadInFrames) / CGFloat(max(1, animationFrameCount - 1))
            }
            guard let buffer = renderer.makePixelBuffer(
                totalProgress: totalProgress,
                independentAnimationEasing: independentAnimationEasing,
                easingCurve: easingCurve
            ) else {
                throw VideoExportError.bufferCreationFailed
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            adaptor.append(buffer, withPresentationTime: presentationTime)
        }

        input.markAsFinished()
        await writer.finishWriting()

        if let error = writer.error {
            throw error
        }

        return targetURL
    }

    @MainActor
    private func chooseExportURL() -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = defaultExportFilename()
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    private func defaultExportFilename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return "FocusShot-\(formatter.string(from: now)).mp4"
    }

    private func videoSize(for image: NSImage) -> CGSize {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: max(cgImage.width, 2), height: max(cgImage.height, 2))
        }

        let reps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        if let rep = reps.max(by: { $0.pixelsWide < $1.pixelsWide }) {
            return CGSize(width: max(rep.pixelsWide, 2), height: max(rep.pixelsHigh, 2))
        }

        return CGSize(width: max(Int(image.size.width), 2), height: max(Int(image.size.height), 2))
    }

}

private struct AnimationFrameRenderer {
    let image: NSImage
    let canvasSize: CGSize
    let highlightRects: [CGRect]
    let opacity: Double
    let strokeWidth: Double
    let independentAnimationEasing: Bool
    let easingCurve: AnimationEasingCurve
    let blendMode: HighlightBlendMode
    let fillColor: NSColor
    let strokeColor: NSColor

    func makePixelBuffer(
        totalProgress: CGFloat,
        independentAnimationEasing: Bool,
        easingCurve: AnimationEasingCurve
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(canvasSize.width),
            Int(canvasSize.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let cgContext = CGContext(
                data: CVPixelBufferGetBaseAddress(pixelBuffer),
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
        else {
            return nil
        }

        cgContext.interpolationQuality = .none
        cgContext.setAllowsAntialiasing(false)
        cgContext.setShouldAntialias(false)

        cgContext.setFillColor(NSColor.clear.cgColor)
        cgContext.fill(CGRect(origin: .zero, size: canvasSize))

        let imageRect = CGRect(origin: .zero, size: canvasSize)
        if let cgImage = cgImage(from: image) {
            cgContext.draw(cgImage, in: imageRect)
        }

        let timeline = AnimationTimeline(
            totalProgress: totalProgress,
            stepCount: highlightRects.count,
            independentAnimationEasing: independentAnimationEasing,
            easingCurve: easingCurve
        )

        HighlightSequenceRenderer.draw(
            in: cgContext,
            highlightRects: highlightRects,
            progresses: timeline.stepProgresses,
            opacity: opacity,
            strokeWidth: strokeWidth,
            blendMode: blendMode,
            fillColor: fillColor,
            strokeColor: strokeColor
        )

        return pixelBuffer
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        let rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            ?? image.bestRepresentation(for: rect, context: nil, hints: nil)
            .flatMap { rep in
                let size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
                let nsImage = NSImage(size: size)
                nsImage.addRepresentation(rep)
                return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
    }
}
