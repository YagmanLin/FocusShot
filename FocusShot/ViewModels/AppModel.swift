import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private enum Keys {
        static let hotKey = "focusshot.hotkey"
        static let settings = "focusshot.settings"
    }

    private struct PersistedSettings: Codable {
        let language: AppLanguage
        let fillColorHex: String
        let strokeColorHex: String
        let blendMode: HighlightBlendMode
        let animationOpacity: Double
        let strokeWidth: Double
        let animationDuration: Double
        let independentAnimationEasing: Bool
        let easingCurve: AnimationEasingCurve
        let allowOverlayInScreenRecordings: Bool
        let colorLibraryHexes: [String]

        private enum CodingKeys: String, CodingKey {
            case language
            case fillColorHex
            case strokeColorHex
            case blendMode
            case animationOpacity
            case strokeWidth
            case animationDuration
            case independentAnimationEasing
            case easingCurve
            case allowOverlayInScreenRecordings
            case colorLibraryHexes
        }

        static let `default` = PersistedSettings(
            language: .chinese,
            fillColorHex: "#FFD43B",
            strokeColorHex: "#FFB800",
            blendMode: .normal,
            animationOpacity: 0.28,
            strokeWidth: 2,
            animationDuration: 1.1,
            independentAnimationEasing: true,
            easingCurve: .default,
            allowOverlayInScreenRecordings: true,
            colorLibraryHexes: []
        )

        init(
            language: AppLanguage,
            fillColorHex: String,
            strokeColorHex: String,
            blendMode: HighlightBlendMode,
            animationOpacity: Double,
            strokeWidth: Double,
            animationDuration: Double,
            independentAnimationEasing: Bool,
            easingCurve: AnimationEasingCurve,
            allowOverlayInScreenRecordings: Bool,
            colorLibraryHexes: [String]
        ) {
            self.language = language
            self.fillColorHex = fillColorHex
            self.strokeColorHex = strokeColorHex
            self.blendMode = blendMode
            self.animationOpacity = animationOpacity
            self.strokeWidth = strokeWidth
            self.animationDuration = animationDuration
            self.independentAnimationEasing = independentAnimationEasing
            self.easingCurve = easingCurve
            self.allowOverlayInScreenRecordings = allowOverlayInScreenRecordings
            self.colorLibraryHexes = colorLibraryHexes
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = Self.default

            language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? defaults.language
            fillColorHex = try container.decodeIfPresent(String.self, forKey: .fillColorHex) ?? defaults.fillColorHex
            strokeColorHex = try container.decodeIfPresent(String.self, forKey: .strokeColorHex) ?? defaults.strokeColorHex
            blendMode = try container.decodeIfPresent(HighlightBlendMode.self, forKey: .blendMode) ?? defaults.blendMode
            animationOpacity = try container.decodeIfPresent(Double.self, forKey: .animationOpacity) ?? defaults.animationOpacity
            strokeWidth = try container.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? defaults.strokeWidth
            animationDuration = try container.decodeIfPresent(Double.self, forKey: .animationDuration) ?? defaults.animationDuration
            independentAnimationEasing = try container.decodeIfPresent(Bool.self, forKey: .independentAnimationEasing) ?? defaults.independentAnimationEasing
            easingCurve = try container.decodeIfPresent(AnimationEasingCurve.self, forKey: .easingCurve) ?? defaults.easingCurve
            allowOverlayInScreenRecordings = try container.decodeIfPresent(Bool.self, forKey: .allowOverlayInScreenRecordings) ?? defaults.allowOverlayInScreenRecordings
            colorLibraryHexes = try container.decodeIfPresent([String].self, forKey: .colorLibraryHexes) ?? defaults.colorLibraryHexes
        }
    }

    @Published var latestSelection: CaptureSelection?
    @Published var latestScreenshot: NSImage?
    @Published var animationRegions: [AnimationRegion] = []
    @Published var statusMessage = ""
    @Published var isCaptureInProgress = false
    @Published var launchAtLoginEnabled: Bool
    @Published var language: AppLanguage
    @Published var fillColorHex: String
    @Published var strokeColorHex: String
    @Published var blendMode: HighlightBlendMode
    @Published var animationOpacity: Double
    @Published var strokeWidth: Double
    @Published var animationDuration: Double
    @Published var independentAnimationEasing: Bool
    @Published var easingCurve: AnimationEasingCurve
    @Published var allowOverlayInScreenRecordings: Bool
    @Published var colorLibraryHexes: [String]
    @Published var isExporting = false
    @Published var shortcut: HotKeyShortcut
    @Published private(set) var latestCaptureID = UUID()
    @Published private(set) var isPreviewPlaybackActive = true

    var text: AppText {
        AppText(language: language)
    }

    private let screenshotService = ScreenshotService()
    private let videoExportService = VideoExportService()
    private let launchAtLoginManager = LaunchAtLoginManager.shared
    private let hotKeyManager = HotKeyManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var shouldRestoreMainWindowAfterCapture = false
    private lazy var overlayController = ScreenshotOverlayController { [weak self] result in
        Task { @MainActor in
            await self?.handleSelection(result)
        }
    }

    init() {
        let settings = Self.loadSettings()
        launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled
        language = settings.language
        fillColorHex = settings.fillColorHex
        strokeColorHex = settings.strokeColorHex
        blendMode = settings.blendMode
        animationOpacity = settings.animationOpacity
        strokeWidth = settings.strokeWidth
        animationDuration = settings.animationDuration
        independentAnimationEasing = settings.independentAnimationEasing
        easingCurve = settings.easingCurve
        allowOverlayInScreenRecordings = settings.allowOverlayInScreenRecordings
        colorLibraryHexes = settings.colorLibraryHexes
        self.shortcut = Self.loadShortcut()
        hotKeyManager.setHandler { [weak self] in
            self?.startCaptureFromHotKey()
        }
        hotKeyManager.register(shortcut)
        bindSettingsPersistence()
        saveSettings()
        statusMessage = text.statusReady(shortcut: shortcut.displayString)
    }

    func startCapture() {
        guard !isCaptureInProgress else { return }
        isCaptureInProgress = true
        statusMessage = text.statusCaptureOpened
        shouldRestoreMainWindowAfterCapture = AppDelegate.shared?.prepareForCapture() ?? false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard self.isCaptureInProgress else { return }
            self.overlayController.beginCapture(
                fillColor: NSColor(hex: self.fillColorHex) ?? .systemYellow,
                strokeColor: NSColor(hex: self.strokeColorHex) ?? .systemOrange,
                opacity: self.animationOpacity,
                strokeWidth: self.strokeWidth,
                blendMode: self.blendMode,
                language: self.language,
                allowScreenCapture: self.allowOverlayInScreenRecordings
            )
        }
    }

    func cancelCapture() {
        isCaptureInProgress = false
        statusMessage = text.statusCancelled
        overlayController.cancel()
    }

    func reeditLatestCapture() {
        guard !isCaptureInProgress, let latestScreenshot else { return }
        isCaptureInProgress = true
        statusMessage = text.statusReedit
        shouldRestoreMainWindowAfterCapture = AppDelegate.shared?.prepareForCapture() ?? false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard self.isCaptureInProgress else { return }
            self.overlayController.beginEditing(
                selectedImage: latestScreenshot,
                animationRegions: self.animationRegions,
                fillColor: NSColor(hex: self.fillColorHex) ?? .systemYellow,
                strokeColor: NSColor(hex: self.strokeColorHex) ?? .systemOrange,
                opacity: self.animationOpacity,
                strokeWidth: self.strokeWidth,
                blendMode: self.blendMode,
                language: self.language,
                allowScreenCapture: self.allowOverlayInScreenRecordings
            )
        }
    }

    func loadPreviewImage(_ image: NSImage) {
        latestScreenshot = image
        latestSelection = syntheticSelection(for: image)
        animationRegions = []
        latestCaptureID = UUID()
        statusMessage = text.statusImageLoaded
    }

    func updateShortcut(_ shortcut: HotKeyShortcut) {
        guard shortcut.isValid else { return }
        self.shortcut = shortcut
        Self.saveShortcut(shortcut)
        hotKeyManager.register(shortcut)
        statusMessage = text.statusShortcutUpdated(shortcut.displayString)
    }

    func resetShortcutToDefault() {
        updateShortcut(.default)
    }

    func exportMP4() {
        guard !isExporting else { return }

        isExporting = true
        statusMessage = text.statusExporting

        Task {
            do {
                let url = try await videoExportService.exportMP4(
                    image: latestScreenshot,
                    animationRegions: animationRegions,
                    duration: animationDuration,
                    opacity: animationOpacity,
                    strokeWidth: strokeWidth,
                    independentAnimationEasing: independentAnimationEasing,
                    easingCurve: easingCurve,
                    blendMode: blendMode,
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex
                )
                await MainActor.run {
                    self.isExporting = false
                    self.statusMessage = self.text.statusExported(fileName: url.lastPathComponent)
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func setPreviewPlaybackActive(_ isActive: Bool) {
        guard isPreviewPlaybackActive != isActive else { return }
        isPreviewPlaybackActive = isActive
    }

    private func handleSelection(_ result: ScreenshotOverlayController.SelectionResult?) async {
        isCaptureInProgress = false
        defer {
            if shouldRestoreMainWindowAfterCapture {
                AppDelegate.shared?.restoreMainWindowAfterCaptureIfNeeded()
            }
            shouldRestoreMainWindowAfterCapture = false
        }

        guard let result else {
            statusMessage = text.statusCancelled
            return
        }

        latestSelection = result.selection
        if let imageOverride = result.imageOverride {
            latestScreenshot = imageOverride
        } else {
            try? await Task.sleep(for: .milliseconds(120))
            latestScreenshot = screenshotService.captureImage(for: result.selection)
            if latestScreenshot == nil {
                try? await Task.sleep(for: .milliseconds(120))
                latestScreenshot = screenshotService.captureImage(for: result.selection)
            }
        }
        animationRegions = result.animationRegions
        latestCaptureID = UUID()
        if latestScreenshot == nil {
            statusMessage = text.statusCaptureEmpty
        } else {
            statusMessage = text.statusCaptureConfirmed(count: animationRegions.count)
            exportMP4()
        }
    }

    private func syntheticSelection(for image: NSImage) -> CaptureSelection {
        let screenFrame = NSScreen.main?.frame ?? CGRect(origin: .zero, size: image.size)
        let selectionRect = CGRect(
            x: screenFrame.midX - image.size.width / 2,
            y: screenFrame.midY - image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        ).integral
        return CaptureSelection(screenFrame: screenFrame, selectionRect: selectionRect)
    }

    private func startCaptureFromHotKey() {
        NSApp.activate(ignoringOtherApps: true)
        startCapture()
    }

    private static func loadShortcut() -> HotKeyShortcut {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.hotKey),
            let shortcut = try? JSONDecoder().decode(HotKeyShortcut.self, from: data)
        else {
            return .default
        }
        return shortcut
    }

    private static func saveShortcut(_ shortcut: HotKeyShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: Keys.hotKey)
    }

    private func bindSettingsPersistence() {
        $language
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveSettings()
                guard let self else { return }
                if !self.isCaptureInProgress {
                    self.statusMessage = self.text.statusReady(shortcut: self.shortcut.displayString)
                }
            }
            .store(in: &cancellables)

        $launchAtLoginEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.updateLaunchAtLogin(isEnabled)
            }
            .store(in: &cancellables)

        $fillColorHex
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $strokeColorHex
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $blendMode
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $animationOpacity
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $strokeWidth
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $animationDuration
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $independentAnimationEasing
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $easingCurve
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $allowOverlayInScreenRecordings
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $colorLibraryHexes
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
    }

    private func saveSettings() {
        let settings = PersistedSettings(
            language: language,
            fillColorHex: fillColorHex,
            strokeColorHex: strokeColorHex,
            blendMode: blendMode,
            animationOpacity: animationOpacity,
            strokeWidth: strokeWidth,
            animationDuration: animationDuration,
            independentAnimationEasing: independentAnimationEasing,
            easingCurve: easingCurve,
            allowOverlayInScreenRecordings: allowOverlayInScreenRecordings,
            colorLibraryHexes: colorLibraryHexes
        )

        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Keys.settings)
    }

    private static func loadSettings() -> PersistedSettings {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.settings),
            let settings = try? JSONDecoder().decode(PersistedSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(isEnabled)
        } catch {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            statusMessage = error.localizedDescription
        }
    }
}
