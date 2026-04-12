import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}

struct AppText {
    let language: AppLanguage

    var startCapture: String { localized(chinese: "开始截图", english: "Start Capture") }
    var captureInProgress: String { localized(chinese: "截图中", english: "Capturing") }
    var exportMP4: String { localized(chinese: "导出 MP4", english: "Export MP4") }
    var exportInProgress: String { localized(chinese: "导出中", english: "Exporting") }
    var animationSettings: String { localized(chinese: "动画参数", english: "Animation") }
    var easingCurveTitle: String { localized(chinese: "速度曲线", english: "Easing Curve") }
    var styleSettings: String { localized(chinese: "样式参数", english: "Style") }
    var fillColor: String { localized(chinese: "填充颜色", english: "Fill Color") }
    var strokeColor: String { localized(chinese: "描边颜色", english: "Stroke Color") }
    var totalAnimationDuration: String { localized(chinese: "总动画时长", english: "Total Duration") }
    var secondsUnit: String { localized(chinese: "秒", english: "s") }
    var independentAnimation: String { localized(chinese: "独立动画", english: "Independent Easing") }
    var independentAnimationEnabled: String { localized(chinese: "每个矩形单独缓入缓出", english: "Ease each rectangle individually") }
    var independentAnimationDisabled: String { localized(chinese: "整个序列共享一次缓入缓出", english: "Ease the whole sequence as one") }
    var rectangleOpacity: String { localized(chinese: "矩形透明度", english: "Rectangle Opacity") }
    var strokeWidth: String { localized(chinese: "描边粗细", english: "Stroke Width") }
    var blendMode: String { localized(chinese: "叠加模式", english: "Blend Mode") }
    var resetCurve: String { localized(chinese: "恢复默认曲线", english: "Reset Curve") }
    var curveControl1X: String { localized(chinese: "起点 X1", english: "Start X1") }
    var curveControl1Y: String { localized(chinese: "起点 Y1", english: "Start Y1") }
    var curveControl2X: String { localized(chinese: "终点 X2", english: "End X2") }
    var curveControl2Y: String { localized(chinese: "终点 Y2", english: "End Y2") }
    var curvePanelHint: String {
        localized(
            chinese: "拖动拉杆调整贝塞尔速度曲线，预览和导出会共用这条节奏。",
            english: "Adjust the bezier speed curve with the sliders. Preview and export use the same timing."
        )
    }
    var preview: String { localized(chinese: "预览", english: "Preview") }
    var noScreenshotTitle: String { localized(chinese: "还没有截图", english: "No Capture Yet") }
    var noScreenshotDescription: String { localized(chinese: "点击左侧“开始截图”，拖拽框选后这里会显示动画预览。", english: "Click Start Capture and drag a region. The animation preview will appear here.") }
    var showMainWindow: String { localized(chinese: "显示主界面", english: "Show Main Window") }
    var showOverlayInRecordings: String { localized(chinese: "录屏时显示截图层", english: "Show Overlay While Recording") }
    var configureScreenshotShortcut: String { localized(chinese: "设置截图快捷键…", english: "Set Screenshot Shortcut…") }
    var resetDefaultShortcut: String { localized(chinese: "恢复默认截图快捷键", english: "Reset Default Screenshot Shortcut") }
    var screenshotShortcutLabel: String { localized(chinese: "截图快捷键", english: "Screenshot Shortcut") }
    var quitApp: String { localized(chinese: "退出 FocusShot", english: "Quit FocusShot") }
    var settingsTitle: String { localized(chinese: "设置", english: "Settings") }
    var languageTitle: String { localized(chinese: "界面语言", english: "Interface Language") }
    var languageHint: String { localized(chinese: "切换后主界面、帮助和菜单会立即更新。", english: "Main UI, help, and menu text update immediately.") }
    var launchAtLoginTitle: String { localized(chinese: "开机启动", english: "Launch at Login") }
    var launchAtLoginHint: String {
        localized(
            chinese: "开启后 FocusShot 会在登录 macOS 时自动启动。",
            english: "When enabled, FocusShot starts automatically when you log in to macOS."
        )
    }
    var aboutMenuTitle: String { localized(chinese: "关于 FocusShot", english: "About FocusShot") }
    var helpMenuTitle: String { localized(chinese: "FocusShot 帮助", english: "FocusShot Help") }
    var aboutHeadline: String { localized(chinese: "FocusShot 是一款用于制作“画重点”矩形动画的轻量截图工具。", english: "FocusShot is a lightweight screenshot tool for creating highlight-style rectangle animations.") }
    var aboutBody: String {
        localized(
            chinese: "它支持先框选截图区域，再按顺序绘制多个矩形，预览与导出共用同一套动画逻辑，并可直接导出为 MP4。",
            english: "It lets you capture an area, draw multiple rectangles in order, preview the exact same animation logic used for export, and render directly to MP4."
        )
    }
    var helpBody: String {
        localized(
            chinese: "1. 点击“开始截图”或使用快捷键进入截图模式。\n2. 先拖拽选取截图区域，再在同一区域绘制一个或多个矩形。\n3. 按 Enter 完成并自动更新预览，按 Command+E 导出视频。\n4. 双击预览可重新进入矩形编辑，也可以把图片拖进预览区继续标注。",
            english: "1. Click Start Capture or use the shortcut to enter capture mode.\n2. Drag to select the capture area, then draw one or more rectangles inside it.\n3. Press Enter to finish and update the preview, then press Command+E to export.\n4. Double-click the preview to re-enter rectangle editing, or drag an image into the preview to annotate it."
        )
    }
    var shortcutRecorderTitle: String { localized(chinese: "按下新的截图快捷键", english: "Press a New Screenshot Shortcut") }
    func currentShortcut(_ value: String) -> String {
        localized(chinese: "当前：\(value)", english: "Current: \(value)")
    }
    var shortcutRecorderHint: String { localized(chinese: "按 Esc 取消，至少包含一个修饰键。", english: "Press Esc to cancel. At least one modifier key is required.") }
    var cancel: String { localized(chinese: "取消", english: "Cancel") }

    var statusReady: String { localized(chinese: "准备开始。点击“开始截图”进入全屏框选。", english: "Ready. Click Start Capture to begin selecting an area.") }
    func statusReady(shortcut: String) -> String {
        localized(
            chinese: "准备开始。点击“开始截图”或按 \(shortcut) 进入全屏框选。",
            english: "Ready. Click Start Capture or press \(shortcut) to begin selecting an area."
        )
    }
    var statusCaptureOpened: String { localized(chinese: "截图模式已开启。拖拽选择区域，按 Esc 可取消。", english: "Capture mode is active. Drag to select an area. Press Esc to cancel.") }
    var statusCancelled: String { localized(chinese: "已取消截图。", english: "Capture cancelled.") }
    var statusReedit: String { localized(chinese: "已回到截图编辑模式。调整矩形后按 Enter 完成。", english: "Returned to rectangle editing. Adjust the rectangles and press Enter to finish.") }
    var statusImageLoaded: String { localized(chinese: "图片已载入。双击预览区进入矩形编辑。", english: "Image loaded. Double-click the preview to enter rectangle editing.") }
    func statusShortcutUpdated(_ shortcut: String) -> String {
        localized(chinese: "快捷键已更新为 \(shortcut)。", english: "Shortcut updated to \(shortcut).")
    }
    var statusExporting: String { localized(chinese: "正在导出 MP4...", english: "Exporting MP4...") }
    func statusExported(fileName: String) -> String {
        localized(chinese: "MP4 已导出到 \(fileName)", english: "MP4 exported to \(fileName)")
    }
    var statusCaptureEmpty: String {
        localized(
            chinese: "区域已经选中了，但截图结果为空。请先确认 Xcode 或 FocusShot 已打开屏幕录制权限。",
            english: "The region was selected, but the captured image is empty. Please make sure screen recording permission is enabled for Xcode or FocusShot."
        )
    }
    func statusCaptureConfirmed(count: Int) -> String {
        localized(
            chinese: "截图和 \(count) 个动画矩形已确认，会按绘制顺序依次播放。",
            english: "Capture and \(count) animation rectangles confirmed. They will play in drawing order."
        )
    }

    var overlayCaptureInstruction: String {
        localized(
            chinese: "先拖拽选择截图范围，松手后继续在同一界面画动画矩形。按 Esc 取消。",
            english: "Drag to select the capture region, then draw highlight rectangles on the same overlay. Press Esc to cancel."
        )
    }
    var overlayFloatingInstruction: String {
        localized(
            chinese: "在图片上继续编辑矩形。按 Enter 完成，Command+Z 撤销。",
            english: "Continue editing rectangles on the image. Press Enter to finish, Command+Z to undo."
        )
    }
    var overlayHighlightInstruction: String {
        localized(
            chinese: "第二步：在截图区域内连续绘制多个矩形。按 Enter 完成，Command+Z 撤销。",
            english: "Step 2: Draw multiple rectangles inside the captured region. Press Enter to finish, Command+Z to undo."
        )
    }

    func rectangleCount(_ count: Int) -> String {
        localized(chinese: "\(count) 个矩形", english: "\(count) rectangles")
    }

    func blendModeTitle(for mode: HighlightBlendMode) -> String {
        switch mode {
        case .normal:
            return localized(chinese: "正常", english: "Normal")
        case .multiply:
            return localized(chinese: "正片叠底", english: "Multiply")
        case .screen:
            return localized(chinese: "滤色", english: "Screen")
        case .overlay:
            return localized(chinese: "叠加", english: "Overlay")
        case .softLight:
            return localized(chinese: "柔光", english: "Soft Light")
        }
    }

    private func localized(chinese: String, english: String) -> String {
        switch language {
        case .chinese:
            return chinese
        case .english:
            return english
        }
    }
}
