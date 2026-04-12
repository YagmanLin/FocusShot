import AppKit
import SwiftUI

extension NSColor {
    convenience init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#FFD43B" }
        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    var rgbComponents: (red: Double, green: Double, blue: Double) {
        let rgb = usingColorSpace(.sRGB) ?? .systemYellow
        return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }

    var hsbaComponents: (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        let color = usingColorSpace(.deviceRGB) ?? .systemYellow
        return (
            hue: Double(color.hueComponent),
            saturation: Double(color.saturationComponent),
            brightness: Double(color.brightnessComponent),
            alpha: Double(color.alphaComponent)
        )
    }

    convenience init(red: Double, green: Double, blue: Double) {
        self.init(
            red: CGFloat(max(0, min(1, red))),
            green: CGFloat(max(0, min(1, green))),
            blue: CGFloat(max(0, min(1, blue))),
            alpha: 1
        )
    }

    convenience init(hue: Double, saturation: Double, brightness: Double) {
        self.init(
            hue: CGFloat(max(0, min(1, hue))),
            saturation: CGFloat(max(0, min(1, saturation))),
            brightness: CGFloat(max(0, min(1, brightness))),
            alpha: 1
        )
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex) ?? .systemYellow)
    }

    init(hue: Double, saturation: Double, brightness: Double) {
        self.init(nsColor: NSColor(hue: hue, saturation: saturation, brightness: brightness))
    }
}

extension String {
    var normalizedHexColor: String? {
        let sanitized = trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard sanitized.count == 6, Int(sanitized, radix: 16) != nil else {
            return nil
        }
        return "#\(sanitized)"
    }
}
