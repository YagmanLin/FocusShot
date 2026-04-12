import AppKit
import CoreGraphics
import SwiftUI

enum HighlightBlendMode: String, CaseIterable, Codable, Identifiable {
    case normal
    case multiply
    case screen
    case overlay
    case softLight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "正常"
        case .multiply: return "正片叠底"
        case .screen: return "滤色"
        case .overlay: return "叠加"
        case .softLight: return "柔光"
        }
    }

    func title(in language: AppLanguage) -> String {
        AppText(language: language).blendModeTitle(for: self)
    }

    var swiftUIBlendMode: BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        }
    }

    var graphicsBlendMode: GraphicsContext.BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        }
    }

    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        }
    }
}
