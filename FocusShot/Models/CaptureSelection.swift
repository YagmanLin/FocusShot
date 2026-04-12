import CoreGraphics
import Foundation

struct CaptureSelection: Equatable, Sendable {
    let screenFrame: CGRect
    let selectionRect: CGRect

    var normalizedRect: CGRect {
        CGRect(
            x: selectionRect.minX - screenFrame.minX,
            y: selectionRect.minY - screenFrame.minY,
            width: selectionRect.width,
            height: selectionRect.height
        )
    }

    var sizeDescription: String {
        "\(Int(selectionRect.width)) x \(Int(selectionRect.height))"
    }

    var topLeftRect: CGRect {
        CGRect(
            x: selectionRect.minX,
            y: screenFrame.maxY - selectionRect.maxY,
            width: selectionRect.width,
            height: selectionRect.height
        )
    }
}
