import CoreGraphics
import Foundation

struct AnimationRegion: Equatable, Sendable {
    let normalizedRect: CGRect

    init(normalizedRect: CGRect) {
        self.normalizedRect = normalizedRect.standardized
    }

    var sizeDescription: String {
        "\(Int(normalizedRect.width * 100))% x \(Int(normalizedRect.height * 100))%"
    }
}
