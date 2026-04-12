import AppKit
import SwiftUI

struct MainView: View {
    private enum ActiveColorPanel {
        case fill
        case stroke
    }

    private enum ActiveInspector: Hashable {
        case animation
        case curve
        case style
    }

    @EnvironmentObject private var appModel: AppModel
    @State private var activeColorPanel: ActiveColorPanel?
    @State private var activeInspector: ActiveInspector?

    private var text: AppText {
        appModel.text
    }

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            previewPanel
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MainWindowAccessor())
    }

    private var topToolbar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                toolbarIconButton(
                    systemImage: "camera.viewfinder",
                    isActive: false,
                    tint: .primary,
                    isDisabled: appModel.isCaptureInProgress
                ) {
                    activeInspector = nil
                    activeColorPanel = nil
                    appModel.startCapture()
                }
                .help(appModel.isCaptureInProgress ? text.captureInProgress : text.startCapture)

                toolbarIconButton(
                    systemImage: "square.and.arrow.up",
                    isActive: false,
                    tint: .primary,
                    isDisabled: appModel.isCaptureInProgress || appModel.isExporting || appModel.latestScreenshot == nil || appModel.animationRegions.isEmpty
                ) {
                    activeInspector = nil
                    activeColorPanel = nil
                    appModel.exportMP4()
                }
                .help(appModel.isExporting ? text.exportInProgress : text.exportMP4)
                .keyboardShortcut("e", modifiers: .command)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(toolbarGroupBackground)

            HStack(spacing: 4) {
                toolbarInspectorButton(
                    helpText: text.animationSettings,
                    systemImage: "sparkles.rectangle.stack",
                    isActive: activeInspector == .animation
                ) {
                    toggleInspector(.animation)
                }
                .popover(isPresented: inspectorBinding(for: .animation), arrowEdge: .top) {
                    animationInspector
                        .frame(width: 280)
                        .padding(12)
                }

                toolbarInspectorButton(
                    helpText: text.easingCurveTitle,
                    systemImage: "chart.line.uptrend.xyaxis",
                    isActive: activeInspector == .curve
                ) {
                    toggleInspector(.curve)
                }
                .popover(isPresented: inspectorBinding(for: .curve), arrowEdge: .top) {
                    easingCurveInspector
                        .frame(width: 320)
                        .padding(12)
                }

                toolbarInspectorButton(
                    helpText: text.styleSettings,
                    systemImage: "slider.horizontal.3",
                    isActive: activeInspector == .style
                ) {
                    toggleInspector(.style)
                }
                .popover(isPresented: inspectorBinding(for: .style), arrowEdge: .top) {
                    styleInspector
                        .frame(width: 300)
                        .padding(12)
                }

                toolbarColorButton(helpText: text.fillColor, systemImage: "paintpalette.fill", hex: appModel.fillColorHex, isOpen: activeColorPanel == .fill) {
                    activeInspector = nil
                    activeColorPanel = activeColorPanel == .fill ? nil : .fill
                }
                .popover(isPresented: colorPanelBinding(for: .fill), arrowEdge: .top) {
                    CompactColorPickerPanel(
                        selectedHex: $appModel.fillColorHex,
                        savedHexes: $appModel.colorLibraryHexes
                    )
                    .padding(10)
                }

                toolbarColorButton(helpText: text.strokeColor, systemImage: "square.dashed", hex: appModel.strokeColorHex, isOpen: activeColorPanel == .stroke) {
                    activeInspector = nil
                    activeColorPanel = activeColorPanel == .stroke ? nil : .stroke
                }
                .popover(isPresented: colorPanelBinding(for: .stroke), arrowEdge: .top) {
                    CompactColorPickerPanel(
                        selectedHex: $appModel.strokeColorHex,
                        savedHexes: $appModel.colorLibraryHexes
                    )
                    .padding(10)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(toolbarGroupBackground)

            Spacer(minLength: 0)
        }
    }

    private var toolbarGroupBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            )
    }

    private var animationInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text.animationSettings)
                .font(.headline)

            LabeledSlider(title: text.totalAnimationDuration, valueText: "\(appModel.animationDuration.formatted(.number.precision(.fractionLength(1)))) \(text.secondsUnit)") {
                WheelSlider(value: $appModel.animationDuration, in: 0.4 ... 8.0, step: 0.1)
            }

            Toggle(isOn: $appModel.independentAnimationEasing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.independentAnimation)
                    Text(appModel.independentAnimationEasing ? text.independentAnimationEnabled : text.independentAnimationDisabled)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var styleInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text.styleSettings)
                .font(.headline)

            LabeledSlider(title: text.rectangleOpacity, valueText: "\(Int(appModel.animationOpacity * 100))%") {
                WheelSlider(value: $appModel.animationOpacity, in: 0 ... 1, step: 0.01)
            }

            LabeledSlider(title: text.strokeWidth, valueText: "\(Int(appModel.strokeWidth)) px") {
                WheelSlider(value: $appModel.strokeWidth, in: 0 ... 12, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(text.blendMode)
                    .font(.subheadline.weight(.medium))

                Picker(text.blendMode, selection: $appModel.blendMode) {
                    ForEach(HighlightBlendMode.allCases) { mode in
                        Text(mode.title(in: appModel.language)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var easingCurveInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(text.easingCurveTitle)
                    .font(.headline)
                Spacer()
                Button(text.resetCurve) {
                    appModel.easingCurve = .default
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }

            EasingCurvePreview(curve: $appModel.easingCurve)
                .frame(width: 292, height: 164)

            Text(text.curvePanelHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HighlightPreviewCard(
                image: appModel.latestScreenshot,
                totalDuration: appModel.animationDuration,
                replayID: appModel.latestCaptureID,
                animationRegions: appModel.animationRegions,
                opacity: appModel.animationOpacity,
                strokeWidth: appModel.strokeWidth,
                independentAnimationEasing: appModel.independentAnimationEasing,
                easingCurve: appModel.easingCurve,
                blendMode: appModel.blendMode,
                fillColor: NSColor(hex: appModel.fillColorHex) ?? .systemYellow,
                strokeColor: NSColor(hex: appModel.strokeColorHex) ?? .systemOrange,
                isPlaybackActive: appModel.isPreviewPlaybackActive,
                text: text,
                onDoubleClick: {
                    appModel.reeditLatestCapture()
                },
                onImageImported: { image in
                    appModel.loadPreviewImage(image)
                }
            )

        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func toolbarColorButton(
        helpText: String,
        systemImage: String,
        hex: String,
        isOpen: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        isOpen
                        ? Color.accentColor.opacity(0.12)
                        : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.8))
                    .offset(x: -2, y: -2)
            }
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    @ViewBuilder
    private func toolbarInspectorButton(
        helpText: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(
                    isActive
                    ? Color.accentColor.opacity(0.12)
                    : Color.black.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    @ViewBuilder
    private func toolbarIconButton(
        systemImage: String,
        isActive: Bool,
        tint: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    isActive
                    ? Color.accentColor.opacity(0.12)
                    : Color.black.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private func toggleInspector(_ inspector: ActiveInspector) {
        activeColorPanel = nil
        activeInspector = activeInspector == inspector ? nil : inspector
    }

    private func inspectorBinding(for inspector: ActiveInspector) -> Binding<Bool> {
        Binding(
            get: { activeInspector == inspector },
            set: { newValue in
                if !newValue, activeInspector == inspector {
                    activeInspector = nil
                }
            }
        )
    }

    private func colorPanelBinding(for panel: ActiveColorPanel) -> Binding<Bool> {
        Binding(
            get: { activeColorPanel == panel },
            set: { newValue in
                if !newValue, activeColorPanel == panel {
                    activeColorPanel = nil
                } else if newValue {
                    activeInspector = nil
                    activeColorPanel = panel
                }
            }
        )
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowAccessorNSView {
        MainWindowAccessorNSView()
    }

    func updateNSView(_ nsView: MainWindowAccessorNSView, context: Context) {
        DispatchQueue.main.async {
            nsView.registerWindow()
        }
    }
}

private final class MainWindowAccessorNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerWindow()
    }

    func registerWindow() {
        guard let window else { return }
        AppDelegate.shared?.registerMainWindow(window)
    }
}

private struct LabeledSlider<Content: View>: View {
    let title: String
    let valueText: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content
            Text(valueText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WheelSlider: NSViewRepresentable {
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double

    init(value: Binding<Double>, in bounds: ClosedRange<Double>, step: Double) {
        _value = value
        self.bounds = bounds
        self.step = step
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> ScrollableSlider {
        let slider = ScrollableSlider(value: value, minValue: bounds.lowerBound, maxValue: bounds.upperBound, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
        slider.step = step
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: ScrollableSlider, context: Context) {
        nsView.minValue = bounds.lowerBound
        nsView.maxValue = bounds.upperBound
        nsView.step = step
        if abs(nsView.doubleValue - value) > .ulpOfOne {
            nsView.doubleValue = value
        }
    }

    final class Coordinator: NSObject {
        @Binding var value: Double

        init(value: Binding<Double>) {
            _value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value = sender.doubleValue
        }
    }
}

private final class ScrollableSlider: NSSlider {
    var step: Double = 0.1

    override func scrollWheel(with event: NSEvent) {
        let dominantDelta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
            ? event.scrollingDeltaY
            : -event.scrollingDeltaX
        guard dominantDelta != 0 else {
            super.scrollWheel(with: event)
            return
        }

        let direction = dominantDelta > 0 ? 1.0 : -1.0
        let nextValue = min(maxValue, max(minValue, doubleValue + direction * step))
        guard nextValue != doubleValue else { return }
        doubleValue = nextValue
        sendAction(action, to: target)
    }
}

private struct EasingCurvePreview: View {
    @Binding var curve: AnimationEasingCurve

    private enum Handle {
        case first
        case second
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .local).insetBy(dx: 14, dy: 14)
            let start = CGPoint(x: frame.minX, y: frame.maxY)
            let end = CGPoint(x: frame.maxX, y: frame.minY)
            let control1 = CGPoint(
                x: frame.minX + frame.width * curve.controlPoint1X,
                y: frame.maxY - frame.height * curve.controlPoint1Y
            )
            let control2 = CGPoint(
                x: frame.minX + frame.width * curve.controlPoint2X,
                y: frame.maxY - frame.height * curve.controlPoint2Y
            )

            ZStack {
                Canvas { context, _ in
                    var grid = Path()
                    for index in 0...4 {
                        let x = frame.minX + frame.width * CGFloat(index) / 4
                        grid.move(to: CGPoint(x: x, y: frame.minY))
                        grid.addLine(to: CGPoint(x: x, y: frame.maxY))
                        let y = frame.minY + frame.height * CGFloat(index) / 4
                        grid.move(to: CGPoint(x: frame.minX, y: y))
                        grid.addLine(to: CGPoint(x: frame.maxX, y: y))
                    }
                    context.stroke(grid, with: .color(Color.black.opacity(0.07)), lineWidth: 1)

                    var guide = Path()
                    guide.move(to: start)
                    guide.addLine(to: control1)
                    guide.move(to: end)
                    guide.addLine(to: control2)
                    context.stroke(guide, with: .color(Color.accentColor.opacity(0.22)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))

                    var curvePath = Path()
                    curvePath.move(to: start)
                    curvePath.addCurve(to: end, control1: control1, control2: control2)
                    context.stroke(curvePath, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                    for point in [start, end] {
                        let rect = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
                        context.fill(
                            Ellipse().path(in: rect),
                            with: .color(Color.black.opacity(0.34))
                        )
                    }
                }

                curveHandle(at: control1, handle: .first, in: frame)
                curveHandle(at: control2, handle: .second, in: frame)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
        )
    }

    private func curveHandle(at point: CGPoint, handle: Handle, in frame: CGRect) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.16), radius: 4, y: 1)
            .contentShape(Rectangle().inset(by: -10))
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateCurve(for: handle, location: value.location, frame: frame)
                    }
            )
    }

    private func updateCurve(for handle: Handle, location: CGPoint, frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return }

        let x = max(0, min(1, (location.x - frame.minX) / frame.width))
        let y = max(0, min(1, 1 - (location.y - frame.minY) / frame.height))

        switch handle {
        case .first:
            curve.controlPoint1X = x
            curve.controlPoint1Y = y
        case .second:
            curve.controlPoint2X = x
            curve.controlPoint2Y = y
        }
    }
}

private struct HighlightPreviewCard: View {
    let image: NSImage?
    let totalDuration: Double
    let replayID: UUID
    let animationRegions: [AnimationRegion]
    let opacity: Double
    let strokeWidth: Double
    let independentAnimationEasing: Bool
    let easingCurve: AnimationEasingCurve
    let blendMode: HighlightBlendMode
    let fillColor: NSColor
    let strokeColor: NSColor
    let isPlaybackActive: Bool
    let text: AppText
    let onDoubleClick: () -> Void
    let onImageImported: (NSImage) -> Void

    @State private var playbackStart = Date()
    @State private var isHovering = false

    var body: some View {
        HighlightPreviewCardContent(
            image: image,
            animationRegions: animationRegions,
            isPlaybackActive: isPlaybackActive,
            playbackStart: playbackStart,
            totalDuration: totalDuration,
            opacity: opacity,
            strokeWidth: strokeWidth,
            independentAnimationEasing: independentAnimationEasing,
            easingCurve: easingCurve,
            blendMode: blendMode,
            fillColor: fillColor,
            strokeColor: strokeColor,
            text: text
        )
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { restartAnimation() }
        .onChange(of: replayID) { _, _ in restartAnimation() }
        .onChange(of: totalDuration) { _, _ in restartAnimation() }
        .onChange(of: animationRegions) { _, _ in restartAnimation() }
        .onChange(of: opacity) { _, _ in restartAnimation() }
        .onChange(of: strokeWidth) { _, _ in restartAnimation() }
        .onChange(of: independentAnimationEasing) { _, _ in restartAnimation() }
        .onChange(of: easingCurve) { _, _ in restartAnimation() }
        .onChange(of: blendMode) { _, _ in restartAnimation() }
        .onChange(of: fillColor.hexString) { _, _ in restartAnimation() }
        .onChange(of: strokeColor.hexString) { _, _ in restartAnimation() }
        .onChange(of: isPlaybackActive) { _, isActive in
            if isActive {
                restartAnimation()
            }
        }
        .overlay(
            hoverOverlay
        )
        .overlay(
            PreviewInteractionCatcherView(
                onDoubleClick: onDoubleClick,
                onImageImported: onImageImported
            )
        )
        .onHover { isHovering = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 250)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 22))
    }

    private func restartAnimation() {
        playbackStart = Date()
    }

    private var hoverOverlay: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(isHovering && image != nil ? 0.07 : 0))
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .allowsHitTesting(false)
    }
}

private struct HighlightPreviewCardContent: View {
    let image: NSImage?
    let animationRegions: [AnimationRegion]
    let isPlaybackActive: Bool
    let playbackStart: Date
    let totalDuration: Double
    let opacity: Double
    let strokeWidth: Double
    let independentAnimationEasing: Bool
    let easingCurve: AnimationEasingCurve
    let blendMode: HighlightBlendMode
    let fillColor: NSColor
    let strokeColor: NSColor
    let text: AppText

    var body: some View {
        Group {
            if let image {
                imagePreview(for: image)
            } else {
                ContentUnavailableView(
                    text.noScreenshotTitle,
                    systemImage: "viewfinder",
                    description: Text(text.noScreenshotDescription)
                )
            }
        }
    }

    @ViewBuilder
    private func imagePreview(for image: NSImage) -> some View {
        if isPlaybackActive {
            TimelineView(.animation) { context in
                renderer(for: image, date: context.date)
            }
        } else {
            renderer(for: image, progresses: Array(repeating: 1, count: animationRegions.count))
        }
    }

    private func renderer(for image: NSImage, date: Date) -> some View {
        renderer(
            for: image,
            progresses: AnimationTimeline(
                elapsed: date.timeIntervalSince(playbackStart),
                totalDuration: totalDuration,
                stepCount: animationRegions.count,
                independentAnimationEasing: independentAnimationEasing,
                easingCurve: easingCurve
            ).stepProgresses
        )
    }

    private func renderer(for image: NSImage, progresses: [CGFloat]) -> some View {
        HighlightPreviewRenderer(
            image: image,
            animationRegions: animationRegions,
            progresses: progresses,
            opacity: opacity,
            strokeWidth: strokeWidth,
            blendMode: blendMode,
            fillColor: fillColor,
            strokeColor: strokeColor
        )
        .padding(14)
    }
}

private struct PreviewInteractionCatcherView: NSViewRepresentable {
    let onDoubleClick: () -> Void
    let onImageImported: (NSImage) -> Void

    func makeNSView(context: Context) -> PreviewInteractionCatcherNSView {
        let view = PreviewInteractionCatcherNSView()
        view.onDoubleClick = onDoubleClick
        view.onImageImported = onImageImported
        return view
    }

    func updateNSView(_ nsView: PreviewInteractionCatcherNSView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
        nsView.onImageImported = onImageImported
    }
}

private final class PreviewInteractionCatcherNSView: NSView {
    var onDoubleClick: (() -> Void)?
    var onImageImported: ((NSImage) -> Void)?
    private var trackingAreaRef: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.supportedPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(Self.supportedPasteboardTypes)
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 2 else {
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
            return
        }
        onDoubleClick?()
    }

    override func keyDown(with event: NSEvent) {
        let isPasteShortcut = event.charactersIgnoringModifiers?.lowercased() == "v"
            && (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control))

        guard isPasteShortcut else {
            super.keyDown(with: event)
            return
        }

        importImageFromPasteboard(NSPasteboard.general)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canReadImage(from: sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        importImageFromPasteboard(sender.draggingPasteboard)
    }

    @discardableResult
    private func importImageFromPasteboard(_ pasteboard: NSPasteboard) -> Bool {
        guard let image = imageFromPasteboard(pasteboard) else { return false }
        onImageImported?(image)
        return true
    }

    private func imageFromPasteboard(_ pasteboard: NSPasteboard) -> NSImage? {
        // Finder often exposes both a file URL and a TIFF preview of the file icon.
        // Prefer the real file URL first so copied JPG/PNG files do not paste as icons.
        if let image = imageFromPasteboardFileURL(pasteboard) {
            return image
        }

        if let image = imageFromPasteboardImageData(pasteboard) {
            return image
        }

        return nil
    }

    private func canReadImage(from pasteboard: NSPasteboard) -> Bool {
        if imageURL(from: pasteboard) != nil {
            return true
        }

        return Self.imageDataTypes.contains { pasteboard.data(forType: $0) != nil }
    }

    private func imageFromPasteboardFileURL(_ pasteboard: NSPasteboard) -> NSImage? {
        guard let imageURL = imageURL(from: pasteboard) else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    private func imageFromPasteboardImageData(_ pasteboard: NSPasteboard) -> NSImage? {
        for type in Self.imageDataTypes {
            guard let data = pasteboard.data(forType: type), let image = NSImage(data: data) else {
                continue
            }
            return image
        }
        return nil
    }

    private func imageURL(from pasteboard: NSPasteboard) -> URL? {
        if
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL],
            let imageURL = urls.first(where: isSupportedImageURL(_:))
        {
            return imageURL
        }

        for type in Self.fileURLTypes {
            guard let rawValue = pasteboard.string(forType: type) else { continue }

            if let url = URL(string: rawValue), url.isFileURL, isSupportedImageURL(url) {
                return url
            }

            let url = URL(fileURLWithPath: rawValue)
            if isSupportedImageURL(url) {
                return url
            }
        }

        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pasteboard.propertyList(forType: filenamesType) as? [String] {
            return paths
                .map { URL(fileURLWithPath: $0) }
                .first(where: isSupportedImageURL(_:))
        }

        return nil
    }

    private func isSupportedImageURL(_ url: URL) -> Bool {
        let supportedExtensions = ["png", "jpg", "jpeg", "tif", "tiff", "heic", "webp"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static let supportedPasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("public.webp"),
        NSPasteboard.PasteboardType("org.webmproject.webp"),
        NSPasteboard.PasteboardType("NSFilenamesPboardType")
    ]

    private static let fileURLTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        NSPasteboard.PasteboardType("public.file-url")
    ]

    private static let imageDataTypes: [NSPasteboard.PasteboardType] = [
        .png,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("public.webp"),
        NSPasteboard.PasteboardType("org.webmproject.webp"),
        .tiff
    ]
}

private struct HighlightPreviewRenderer: NSViewRepresentable {
    let image: NSImage
    let animationRegions: [AnimationRegion]
    let progresses: [CGFloat]
    let opacity: Double
    let strokeWidth: Double
    let blendMode: HighlightBlendMode
    let fillColor: NSColor
    let strokeColor: NSColor

    func makeNSView(context: Context) -> HighlightPreviewNSView {
        HighlightPreviewNSView()
    }

    func updateNSView(_ nsView: HighlightPreviewNSView, context: Context) {
        nsView.image = image
        nsView.animationRegions = animationRegions
        nsView.progresses = progresses
        nsView.opacity = opacity
        nsView.strokeWidth = strokeWidth
        nsView.blendMode = blendMode
        nsView.fillColor = fillColor
        nsView.strokeColor = strokeColor
        nsView.needsDisplay = true
    }
}

private final class HighlightPreviewNSView: NSView {
    var image: NSImage?
    var animationRegions: [AnimationRegion] = []
    var progresses: [CGFloat] = []
    var opacity: Double = 0.3
    var strokeWidth: Double = 2
    var blendMode: HighlightBlendMode = .normal
    var fillColor: NSColor = .systemYellow
    var strokeColor: NSColor = .systemOrange

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(bounds)

        guard let image else {
            return
        }

        let imageSize = image.size
        let imageRect = fittedRect(for: CGSize(width: imageSize.width, height: imageSize.height), in: bounds.insetBy(dx: 6, dy: 6))
        let cornerRadius: CGFloat = 14
        let imagePath = CGPath(roundedRect: imageRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        context.saveGState()
        context.addPath(imagePath)
        context.clip()
        image.draw(in: imageRect)

        let highlightRects = animationRegions.enumerated().compactMap { index, region -> CGRect? in
            guard index < progresses.count else { return nil }
            return CGRect(
                x: imageRect.minX + imageRect.width * region.normalizedRect.minX,
                y: imageRect.minY + imageRect.height * region.normalizedRect.minY,
                width: imageRect.width * region.normalizedRect.width,
                height: imageRect.height * region.normalizedRect.height
            )
        }

        HighlightSequenceRenderer.draw(
            in: context,
            highlightRects: highlightRects,
            progresses: Array(progresses.prefix(highlightRects.count)),
            opacity: opacity,
            strokeWidth: strokeWidth,
            blendMode: blendMode,
            fillColor: fillColor,
            strokeColor: strokeColor
        )
        context.restoreGState()

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        context.setLineWidth(1)
        context.addPath(imagePath)
        context.strokePath()
    }

    private func fittedRect(for imageSize: CGSize, in container: CGRect) -> CGRect {
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: container.midX - fitted.width / 2,
            y: container.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        ).integral
    }
}
