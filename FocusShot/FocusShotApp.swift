import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate?

    private var mainWindow: NSWindow?
    private var shortcutWindow: NSPanel?
    private var aboutWindow: NSWindow?
    private var helpWindow: NSWindow?
    private var appModel: AppModel?
    private var hasFinishedLaunching = false
    private var hasPresentedInitialWindow = false

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            self.pruneMainMenu()
            self.presentInitialWindowIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func registerMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else { return }
        guard window.level != .screenSaver else { return }
        guard !window.styleMask.contains(.borderless) else { return }

        mainWindow = window
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    func configure(appModel: AppModel) {
        self.appModel = appModel
        presentInitialWindowIfNeeded()
    }

    func showMainWindow(using appModel: AppModel? = nil) {
        if let appModel {
            self.appModel = appModel
        }
        if mainWindow == nil {
            mainWindow = NSApp.windows.first(where: Self.isEligibleMainWindow(_:))
        }
        if mainWindow == nil, let appModel = self.appModel ?? appModel {
            mainWindow = makeMainWindow(using: appModel)
        }

        guard let mainWindow else { return }
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.unhide(nil)
            self.appModel?.setPreviewPlaybackActive(true)
            mainWindow.collectionBehavior.remove(.transient)
            mainWindow.level = .normal
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            if !mainWindow.isVisible {
                mainWindow.setIsVisible(true)
            }
            NSApp.activate(ignoringOtherApps: true)
            NSApp.arrangeInFront(nil)
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
        }
    }

    func showShortcutRecorder(using appModel: AppModel) {
        if shortcutWindow == nil {
            shortcutWindow = makeShortcutWindow(using: appModel)
        }

        guard let shortcutWindow else { return }
        shortcutWindow.title = appModel.text.configureScreenshotShortcut
        if let hostingController = shortcutWindow.contentViewController as? NSHostingController<ShortcutRecorderPanel> {
            hostingController.rootView = ShortcutRecorderPanel(appModel: appModel) { [weak self] in
                self?.shortcutWindow?.orderOut(nil)
            }
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        shortcutWindow.center()
        shortcutWindow.makeKeyAndOrderFront(nil)
        shortcutWindow.orderFrontRegardless()
    }

    func showAbout(using appModel: AppModel) {
        if aboutWindow == nil {
            aboutWindow = makeInfoWindow(
                title: appModel.text.aboutMenuTitle,
                rootView: AboutPanel(appModel: appModel)
            )
        }

        guard let aboutWindow else { return }
        aboutWindow.title = appModel.text.aboutMenuTitle
        if let hostingController = aboutWindow.contentViewController as? NSHostingController<AboutPanel> {
            hostingController.rootView = AboutPanel(appModel: appModel)
        }
        showUtilityWindow(aboutWindow)
    }

    func showHelp(using appModel: AppModel) {
        if helpWindow == nil {
            helpWindow = makeInfoWindow(
                title: appModel.text.helpMenuTitle,
                rootView: HelpPanel(appModel: appModel)
            )
        }

        guard let helpWindow else { return }
        helpWindow.title = appModel.text.helpMenuTitle
        if let hostingController = helpWindow.contentViewController as? NSHostingController<HelpPanel> {
            hostingController.rootView = HelpPanel(appModel: appModel)
        }
        showUtilityWindow(helpWindow)
    }

    func hideMainWindow() {
        appModel?.setPreviewPlaybackActive(false)
        mainWindow?.orderOut(nil)
        updateActivationPolicyForVisibleWindows()
    }

    func prepareForCapture() -> Bool {
        let shouldRestoreMainWindow = mainWindow?.isVisible == true
        let shouldHideShortcutWindow = shortcutWindow?.isVisible == true

        if shouldRestoreMainWindow {
            appModel?.setPreviewPlaybackActive(false)
            mainWindow?.orderOut(nil)
        }

        if shouldHideShortcutWindow {
            shortcutWindow?.orderOut(nil)
        }

        updateActivationPolicyForVisibleWindows()
        return shouldRestoreMainWindow
    }

    func restoreMainWindowAfterCaptureIfNeeded() {
        guard let appModel else { return }
        showMainWindow(using: appModel)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == mainWindow {
            hideMainWindow()
            return false
        }
        DispatchQueue.main.async {
            self.updateActivationPolicyForVisibleWindows()
        }
        return true
    }

    private func makeMainWindow(using appModel: AppModel) -> NSWindow {
        let hostingController = NSHostingController(
            rootView: MainView()
                .environmentObject(appModel)
                .frame(minWidth: 560, minHeight: 340)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "FocusShot"
        window.setContentSize(NSSize(width: 620, height: 360))
        window.minSize = NSSize(width: 560, height: 340)
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowDidMiniaturize(_ notification: Notification) {
        guard notification.object as? NSWindow == mainWindow else { return }
        appModel?.setPreviewPlaybackActive(false)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        guard notification.object as? NSWindow == mainWindow else { return }
        appModel?.setPreviewPlaybackActive(true)
    }

    private func makeShortcutWindow(using appModel: AppModel) -> NSPanel {
        let hostingController = NSHostingController(
            rootView: ShortcutRecorderPanel(appModel: appModel) { [weak self] in
                self?.shortcutWindow?.orderOut(nil)
            }
        )
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = appModel.text.configureScreenshotShortcut
        panel.styleMask = [.titled, .closable]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.setContentSize(NSSize(width: 320, height: 170))
        return panel
    }

    private func makeInfoWindow<Content: View>(title: String, rootView: Content) -> NSWindow {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 260))
        return window
    }

    private func showUtilityWindow(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @MainActor
    private func presentInitialWindowIfNeeded() {
        guard hasFinishedLaunching, !hasPresentedInitialWindow, let appModel else { return }
        hasPresentedInitialWindow = true
        showMainWindow(using: appModel)
    }

    @MainActor
    private func updateActivationPolicyForVisibleWindows() {
        let hasVisibleMainWindow = mainWindow?.isVisible == true
        let hasVisibleShortcutWindow = shortcutWindow?.isVisible == true

        if hasVisibleMainWindow || hasVisibleShortcutWindow {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
            NSApp.hide(nil)
        }
    }

    @MainActor
    private func pruneMainMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        pruneMenuItems(in: mainMenu)
    }

    @MainActor
    private func pruneMenuItems(in menu: NSMenu) {
        let unwantedFragments = [
            "Start Dictation",
            "开始听写",
            "Emoji & Symbols",
            "表情与符号",
            "Services",
            "服务"
        ]

        for item in menu.items.reversed() {
            if unwantedFragments.contains(where: { item.title.contains($0) }) {
                menu.removeItem(item)
            }
        }

        while menu.items.last?.isSeparatorItem == true {
            menu.removeItem(at: menu.items.count - 1)
        }

        for item in menu.items {
            if let submenu = item.submenu {
                pruneMenuItems(in: submenu)
            }
        }
    }

    nonisolated private static func isEligibleMainWindow(_ window: NSWindow) -> Bool {
        window.level != .screenSaver && !window.styleMask.contains(.borderless)
    }
}

@main
struct FocusShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        let _ = appDelegate.configure(appModel: appModel)
        MenuBarExtra("FocusShot", systemImage: "camera.viewfinder") {
            Button(appModel.text.showMainWindow) {
                appDelegate.showMainWindow(using: appModel)
            }

            Button(appModel.text.startCapture) {
                appModel.startCapture()
            }

            Button(appModel.text.exportMP4) {
                appModel.exportMP4()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(appModel.isCaptureInProgress || appModel.isExporting || appModel.latestScreenshot == nil || appModel.animationRegions.isEmpty)

            Divider()

            Toggle(appModel.text.showOverlayInRecordings, isOn: $appModel.allowOverlayInScreenRecordings)

            Divider()

            Text("\(appModel.text.screenshotShortcutLabel) \(appModel.shortcut.displayString)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Button(appModel.text.configureScreenshotShortcut) {
                appDelegate.showShortcutRecorder(using: appModel)
            }

            Button(appModel.text.resetDefaultShortcut) {
                appModel.resetShortcutToDefault()
            }

            Divider()

            Button(appModel.text.quitApp) {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsPanel(appModel: appModel)
                .frame(width: 420, height: 220)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(appModel.text.aboutMenuTitle) {
                    appDelegate.showAbout(using: appModel)
                }
            }

            CommandGroup(replacing: .help) {
                Button(appModel.text.helpMenuTitle) {
                    appDelegate.showHelp(using: appModel)
                }
            }
        }
    }
}

private struct ShortcutRecorderPanel: View {
    @ObservedObject var appModel: AppModel
    let onClose: () -> Void

    @State private var isRecording = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appModel.text.shortcutRecorderTitle)
                .font(.system(size: 15, weight: .semibold))

            Text(appModel.text.currentShortcut(appModel.shortcut.displayString))
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())

            Text(appModel.text.shortcutRecorderHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(appModel.text.cancel) {
                    isRecording = false
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }

            ShortcutRecorderView(isRecording: $isRecording) { shortcut in
                appModel.updateShortcut(shortcut)
                isRecording = false
                onClose()
            } onCancel: {
                isRecording = false
                onClose()
            }
            .frame(height: 0)
        }
        .padding(16)
        .frame(width: 320)
    }
}

private struct SettingsPanel: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(appModel.text.settingsTitle)
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    Text(appModel.text.languageTitle)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 92, alignment: .leading)

                    Picker("", selection: $appModel.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Text(appModel.text.languageHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 106)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    Text(appModel.text.launchAtLoginTitle)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 92, alignment: .leading)

                    Toggle("", isOn: $appModel.launchAtLoginEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Text(appModel.text.launchAtLoginHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 106)
            }

            Spacer()
        }
        .padding(18)
    }
}

private struct AboutPanel: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FocusShot")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(appModel.text.aboutHeadline)
                .font(.system(size: 14, weight: .semibold))

            Text(appModel.text.aboutBody)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(20)
    }
}

private struct HelpPanel: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appModel.text.helpMenuTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text(appModel.text.helpBody)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(20)
    }
}
