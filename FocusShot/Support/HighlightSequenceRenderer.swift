import CoreGraphics
import SwiftUI

enum HighlightSequenceRenderer {
    static func draw(
        in context: GraphicsContext,
        size: CGSize,
        regions: [AnimationRegion],
        progresses: [CGFloat],
        opacity: Double,
        strokeWidth: Double,
        fillColor: Color,
        strokeColor: Color
    ) {
        for (index, region) in regions.enumerated() {
            guard index < progresses.count else { continue }
            let rect = CGRect(
                x: size.width * region.normalizedRect.minX,
                y: size.height * region.normalizedRect.minY,
                width: size.width * region.normalizedRect.width,
                height: size.height * region.normalizedRect.height
            )
            let revealWidth = floor(max(0, min(rect.width, rect.width * progresses[index])))
            guard revealWidth > 0 else { continue }

            let revealRect = CGRect(x: rect.minX, y: rect.minY, width: revealWidth, height: rect.height).integral
            let revealPath = Path(revealRect)
            let strokeRect = revealRect.insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
            let strokePath = Path(strokeRect)

            context.drawLayer { layer in
                layer.fill(revealPath, with: .color(fillColor.opacity(opacity)))
                if strokeWidth > 0 {
                    layer.stroke(strokePath, with: .color(strokeColor.opacity(0.95)), lineWidth: strokeWidth)
                }
            }
        }
    }

    static func draw(
        in cgContext: CGContext,
        highlightRects: [CGRect],
        progresses: [CGFloat],
        opacity: Double,
        strokeWidth: Double,
        blendMode: HighlightBlendMode,
        fillColor: NSColor,
        strokeColor: NSColor
    ) {
        for (index, rect) in highlightRects.enumerated() {
            guard index < progresses.count else { continue }
            let revealWidth = floor(max(0, min(rect.width, rect.width * progresses[index])))
            guard revealWidth > 0 else { continue }

            let revealRect = CGRect(x: rect.minX, y: rect.minY, width: revealWidth, height: rect.height).integral

            cgContext.saveGState()
            cgContext.setBlendMode(blendMode.cgBlendMode)
            cgContext.setFillColor(fillColor.withAlphaComponent(opacity).cgColor)
            cgContext.fill(revealRect)
            if strokeWidth > 0 {
                let strokeRect = revealRect.insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
                cgContext.setStrokeColor(strokeColor.withAlphaComponent(0.95).cgColor)
                cgContext.setLineWidth(strokeWidth)
                cgContext.stroke(strokeRect)
            }
            cgContext.restoreGState()
        }
    }
}
