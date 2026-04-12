import AppKit
import SwiftUI

@MainActor
final class ScreenshotOverlayController: NSObject {
    struct SelectionResult {
        let selection: CaptureSelection
        let animationRegions: [AnimationRegion]
        let imageOverride: NSImage?
    }

    private let onComplete: (SelectionResult?) -> Void
    private var window: OverlayWindow?
    private var rightClickMonitor: Any?
    private let screenshotService = ScreenshotService()
    init(onComplete: @escaping (SelectionResult?) -> Void) {
        self.onComplete = onComplete
    }

    func beginCapture(
        fillColor: NSColor,
        strokeColor: NSColor,
        opacity: Double,
        strokeWidth: Double,
        blendMode: HighlightBlendMode,
        language: AppLanguage,
        allowScreenCapture: Bool
    ) {
        cancel()

        guard let screen = NSScreen.main else {
            onComplete(nil)
            return
        }

        let overlayView = ScreenshotOverlayView(
            screen: screen,
            backgroundImage: screenshotService.captureScreenImage(for: screen),
            fillColor: fillColor,
            strokeColor: strokeColor,
            opacity: opacity,
            strokeWidth: strokeWidth,
            blendMode: blendMode,
            language: language
        ) { [weak self] result in
            self?.finish(with: result)
        } onCancel: { [weak self] in
            self?.finish(with: nil)
        }

        let hostingView = OverlayHostingView(rootView: overlayView)
        hostingView.frame = screen.frame
        hostingView.autoresizingMask = [.width, .height]

        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.sharingType = allowScreenCapture ? .readOnly : .none
        window.contentView = hostingView
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        installRightClickMonitor()
    }

    func beginEditing(
        selectedImage: NSImage,
        animationRegions: [AnimationRegion],
        fillColor: NSColor,
        strokeColor: NSColor,
        opacity: Double,
        strokeWidth: Double,
        blendMode: HighlightBlendMode,
        language: AppLanguage,
        allowScreenCapture: Bool
    ) {
        cancel()

        guard let screen = NSScreen.main else {
            onComplete(nil)
            return
        }

        let localCaptureRect = centeredImageRect(imageSize: selectedImage.size, in: screen.frame.size)

        let localAnimationRects = animationRegions.map { region in
            CGRect(
                x: localCaptureRect.minX + localCaptureRect.width * region.normalizedRect.minX,
                y: localCaptureRect.minY + localCaptureRect.height * region.normalizedRect.minY,
                width: localCaptureRect.width * region.normalizedRect.width,
                height: localCaptureRect.height * region.normalizedRect.height
            ).integral
        }

        let overlayView = ScreenshotOverlayView(
            screen: screen,
            backgroundImage: nil,
            frozenSelectionImage: selectedImage,
            fillColor: fillColor,
            strokeColor: strokeColor,
            opacity: opacity,
            strokeWidth: strokeWidth,
            blendMode: blendMode,
            language: language,
            initialCaptureRect: localCaptureRect,
            initialAnimationRects: localAnimationRects,
            isFloatingImageEditor: true
        ) { [weak self] result in
            self?.finish(with: result)
        } onCancel: { [weak self] in
            self?.finish(with: nil)
        }

        let hostingView = OverlayHostingView(rootView: overlayView)
        hostingView.frame = screen.frame
        hostingView.autoresizingMask = [.width, .height]

        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.sharingType = allowScreenCapture ? .readOnly : .none
        window.contentView = hostingView
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        installRightClickMonitor()
    }

    private func centeredImageRect(imageSize: NSSize, in screenSize: CGSize) -> CGRect {
        let margin = max(CGFloat(64), min(screenSize.width, screenSize.height) * 0.08)
        let available = CGSize(
            width: max(120, screenSize.width - margin * 2),
            height: max(120, screenSize.height - margin * 2)
        )
        let scale = min(1, available.width / imageSize.width, available.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (screenSize.width - fittedSize.width) / 2,
            y: (screenSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        ).integral
    }

    func cancel() {
        removeRightClickMonitor()
        window?.orderOut(nil)
        window = nil
    }

    private func finish(with result: SelectionResult?) {
        window?.sharingType = .none
        cancel()
        if let result {
            onComplete(result)
        } else {
            onComplete(nil)
        }
    }

    private func installRightClickMonitor() {
        removeRightClickMonitor()

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            guard self.window != nil else { return event }
            self.finish(with: nil)
            return nil
        }
    }

    private func removeRightClickMonitor() {
        if let rightClickMonitor {
            NSEvent.removeMonitor(rightClickMonitor)
            self.rightClickMonitor = nil
        }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct ScreenshotOverlayView: View {
    private struct InstructionRow {
        let shortcuts: [String]
        let description: String
    }

    private enum Phase {
        case capture
        case highlight
    }

    private enum EditableTarget: Equatable {
        case capture
        case animation(Int)
    }

    private enum RectHandle {
        case move
        case left
        case right
        case top
        case bottom
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private enum OverlayCursorStyle: Equatable {
        case arrow
        case crosshair
        case openHand
        case closedHand
        case resizeLeftRight
        case resizeUpDown
        case resizeDiagonalLeading
        case resizeDiagonalTrailing
    }

    private enum DragMode {
        case creatingCapture(start: CGPoint)
        case creatingAnimation(start: CGPoint)
        case editing(
            target: EditableTarget,
            handle: RectHandle,
            initialRect: CGRect,
            initialCaptureRect: CGRect?,
            initialAnimationRects: [CGRect],
            start: CGPoint
        )
    }

    private struct OverlaySnapshot {
        let phase: Phase
        let captureRect: CGRect?
        let animationRects: [CGRect]
        let activeTarget: EditableTarget?
    }

    let screen: NSScreen
    let backgroundImage: NSImage?
    let frozenSelectionImage: NSImage?
    let fillColor: NSColor
    let strokeColor: NSColor
    let opacity: Double
    let strokeWidth: Double
    let blendMode: HighlightBlendMode
    let language: AppLanguage
    let initialCaptureRect: CGRect?
    let initialAnimationRects: [CGRect]
    let isFloatingImageEditor: Bool
    let onFinish: (ScreenshotOverlayController.SelectionResult) -> Void
    let onCancel: () -> Void

    @State private var phase: Phase
    @State private var dragMode: DragMode?
    @State private var previewRect: CGRect?
    @State private var captureRect: CGRect?
    @State private var animationRects: [CGRect]
    @State private var activeTarget: EditableTarget?
    @State private var undoStack: [OverlaySnapshot] = []
    @State private var currentCursorStyle: OverlayCursorStyle = .crosshair
    @State private var lastPointerLocation: CGPoint?
    @State private var floatingZoomScale: CGFloat = 1
    @State private var floatingZoomScrollRemainder: CGFloat = 0
    @State private var zoomIndicatorText: String?
    @State private var zoomIndicatorToken = UUID()

    private let instructionCardWidth: CGFloat = 320
    private let instructionCardHorizontalPadding: CGFloat = 12
    private let instructionCardVerticalPadding: CGFloat = 12
    private let instructionCardRowSpacing: CGFloat = 10
    private let instructionCardInset: CGFloat = 18

    init(
        screen: NSScreen,
        backgroundImage: NSImage?,
        frozenSelectionImage: NSImage? = nil,
        fillColor: NSColor,
        strokeColor: NSColor,
        opacity: Double,
        strokeWidth: Double,
        blendMode: HighlightBlendMode,
        language: AppLanguage,
        initialCaptureRect: CGRect? = nil,
        initialAnimationRects: [CGRect] = [],
        isFloatingImageEditor: Bool = false,
        onFinish: @escaping (ScreenshotOverlayController.SelectionResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screen = screen
        self.backgroundImage = backgroundImage
        self.frozenSelectionImage = frozenSelectionImage
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.opacity = opacity
        self.strokeWidth = strokeWidth
        self.blendMode = blendMode
        self.language = language
        self.initialCaptureRect = initialCaptureRect
        self.initialAnimationRects = initialAnimationRects
        self.isFloatingImageEditor = isFloatingImageEditor
        self.onFinish = onFinish
        self.onCancel = onCancel
        _phase = State(initialValue: initialCaptureRect == nil ? .capture : .highlight)
        _captureRect = State(initialValue: initialCaptureRect)
        _animationRects = State(initialValue: initialAnimationRects)
        _activeTarget = State(initialValue: initialCaptureRect == nil || isFloatingImageEditor ? nil : .capture)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                backgroundLayer(in: proxy.size)
                selectionMask
                    .ignoresSafeArea()
                overlayContent

                if shouldShowInstructionCard(in: proxy.size) {
                    instructionCard
                        .padding(instructionCardInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(in: proxy.size))
            .simultaneousGesture(doubleTapGesture(in: proxy.size))
            .simultaneousGesture(tapGesture(in: proxy.size))
            .background(
                ZStack {
                    KeyCatcherView(
                        onEscape: onCancel,
                        onConfirm: finishSelection,
                        onUndo: performUndo,
                        onDeleteLast: {
                            deleteActiveOrLast()
                        }
                    )

                    PointerTrackingView(
                        onMove: { point in
                            lastPointerLocation = point
                            updateCursor(at: point, in: proxy.size)
                        },
                        onScroll: { deltaY, point in
                            zoomFloatingImageEditor(deltaY: deltaY, at: point, in: proxy.size)
                        },
                        onRightClick: onCancel,
                        onExit: {
                            currentCursorStyle = .arrow
                            applyCursorStyle(.arrow)
                        }
                    )
                }
            )
        }
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: instructionCardRowSpacing) {
            ForEach(Array(instructionRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 6) {
                        ForEach(row.shortcuts, id: \.self) { shortcut in
                            instructionShortcutBadge(shortcut)
                        }
                    }
                    .frame(minWidth: 92, alignment: .leading)

                    Text(row.description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, instructionCardHorizontalPadding)
        .padding(.vertical, instructionCardVerticalPadding)
        .frame(width: instructionCardWidth, alignment: .leading)
        .background(Color.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(.white.opacity(0.14), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 4)
    }

    private func instructionShortcutBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.98))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
    }

    private var instructionRows: [InstructionRow] {
        switch phase {
        case .capture:
            return [
                InstructionRow(shortcuts: [localized(chinese: "拖拽", english: "Drag")], description: localized(chinese: "框选截图区域", english: "Select the capture region")),
                InstructionRow(shortcuts: ["Esc"], description: localized(chinese: "取消截图", english: "Cancel capture")),
                InstructionRow(shortcuts: [localized(chinese: "右键", english: "Right Click")], description: localized(chinese: "直接退出截图层", english: "Dismiss the overlay"))
            ]
        case .highlight:
            if isFloatingImageEditor {
                return [
                    InstructionRow(shortcuts: [localized(chinese: "拖拽", english: "Drag")], description: localized(chinese: "绘制或移动矩形", english: "Draw or move rectangles")),
                    InstructionRow(shortcuts: ["⌥", localized(chinese: "拖拽", english: "Drag")], description: localized(chinese: "复制当前矩形", english: "Duplicate the current rectangle")),
                    InstructionRow(shortcuts: [localized(chinese: "双击", english: "Double Click")], description: localized(chinese: "删除矩形", english: "Delete a rectangle")),
                    InstructionRow(shortcuts: ["↩"], description: localized(chinese: "完成编辑", english: "Finish editing")),
                    InstructionRow(shortcuts: ["⌘", "Z"], description: localized(chinese: "撤销上一步", english: "Undo"))
                ]
            }

            return [
                InstructionRow(shortcuts: [localized(chinese: "拖拽", english: "Drag")], description: localized(chinese: "继续绘制矩形", english: "Draw more rectangles")),
                InstructionRow(shortcuts: ["⌥", localized(chinese: "拖拽", english: "Drag")], description: localized(chinese: "复制当前矩形", english: "Duplicate the current rectangle")),
                InstructionRow(shortcuts: [localized(chinese: "双击", english: "Double Click")], description: localized(chinese: "删除矩形", english: "Delete a rectangle")),
                InstructionRow(shortcuts: ["↩"], description: localized(chinese: "完成并更新预览", english: "Finish and update preview")),
                InstructionRow(shortcuts: ["⌘", "Z"], description: localized(chinese: "撤销上一步", english: "Undo"))
            ]
        }
    }

    private func shouldShowInstructionCard(in size: CGSize) -> Bool {
        let cardFrame = instructionCardFrame(in: size)
        let overlappingRects = [captureRect, previewRect].compactMap { $0 }
        return !overlappingRects.contains { $0.intersects(cardFrame) }
    }

    private func instructionCardFrame(in size: CGSize) -> CGRect {
        let rowHeight: CGFloat = 27
        let height = instructionCardVerticalPadding * 2
            + CGFloat(instructionRows.count) * rowHeight
            + CGFloat(max(0, instructionRows.count - 1)) * instructionCardRowSpacing

        return CGRect(
            x: instructionCardInset,
            y: size.height - instructionCardInset - height,
            width: instructionCardWidth,
            height: height
        )
    }

    private func localized(chinese: String, english: String) -> String {
        switch language {
        case .chinese:
            return chinese
        case .english:
            return english
        }
    }

    @ViewBuilder
    private func backgroundLayer(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            if let backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .ignoresSafeArea()
            } else {
                Color.clear
            }

            if let frozenSelectionImage, let captureRect {
                Image(nsImage: frozenSelectionImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: captureRect.width, height: captureRect.height)
                    .clipShape(RoundedRectangle(cornerRadius: isFloatingImageEditor ? 10 : 0))
                    .shadow(color: .black.opacity(isFloatingImageEditor ? 0.26 : 0), radius: 26, x: 0, y: 14)
                    .position(x: captureRect.midX, y: captureRect.midY)
            }
        }
    }

    private var selectionMask: some View {
        Group {
            if isFloatingImageEditor {
                EmptyView()
            } else {
                ZStack {
                Rectangle()
                    .fill(.black.opacity(0.55))

                    if phase == .capture, let previewRect {
                        Rectangle()
                            .fill(.white)
                            .frame(width: previewRect.width, height: previewRect.height)
                            .position(x: previewRect.midX, y: previewRect.midY)
                            .blendMode(.destinationOut)
                    }

                    if let captureRect {
                        Rectangle()
                            .fill(.white)
                            .frame(width: captureRect.width, height: captureRect.height)
                            .position(x: captureRect.midX, y: captureRect.midY)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
            }
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if let captureRect {
            if isFloatingImageEditor {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .frame(width: captureRect.width, height: captureRect.height)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.clear)
                            .shadow(color: .black.opacity(0.26), radius: 26, x: 0, y: 14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .position(x: captureRect.midX, y: captureRect.midY)
            } else {
                Rectangle()
                    .stroke(activeTarget == .capture ? Color.white.opacity(0.96) : Color.white.opacity(0.78), lineWidth: activeTarget == .capture ? 2 : 1.2)
                    .frame(width: captureRect.width, height: captureRect.height)
                    .position(x: captureRect.midX, y: captureRect.midY)

                label(for: captureRect, color: .white)

                if activeTarget == .capture {
                    handles(for: captureRect, tint: .white)
                }
            }
        }

        if isFloatingImageEditor, let zoomIndicatorText, let captureRect {
            Text(zoomIndicatorText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.88))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 2)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .position(x: captureRect.minX + 34, y: captureRect.minY + 22)
        }

        ForEach(Array(animationRects.enumerated()), id: \.offset) { index, rect in
            let lineWidth = animationStrokeWidth(isSelected: activeTarget == .animation(index))
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: fillColor).opacity(opacity))

                if lineWidth > 0 {
                    Rectangle()
                        .stroke(
                            activeTarget == .animation(index)
                            ? Color(nsColor: strokeColor).opacity(0.95)
                            : Color(nsColor: strokeColor).opacity(0.76),
                            lineWidth: lineWidth
                        )
                        .frame(width: rect.width + lineWidth, height: rect.height + lineWidth)
                }
            }
            .compositingGroup()
            .blendMode(blendMode.swiftUIBlendMode)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)

            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)
                .position(x: rect.minX + 16, y: rect.minY + 16)

            if activeTarget == .animation(index) {
                handles(for: rect, tint: Color(nsColor: strokeColor))
            }
	        }

        if let previewRect {
            ZStack {
                Rectangle()
                    .fill(activeDragFill)

                Rectangle()
                    .stroke(activeDragStroke, lineWidth: activeDragStrokeWidth)
                    .frame(width: previewRect.width + activeDragStrokeWidth, height: previewRect.height + activeDragStrokeWidth)
            }
            .compositingGroup()
            .blendMode(phase == .highlight ? blendMode.swiftUIBlendMode : .normal)
            .frame(width: previewRect.width, height: previewRect.height)
            .position(x: previewRect.midX, y: previewRect.midY)

            label(for: previewRect, color: activeDragStroke)
        }
    }

    private var instructionText: String {
        let text = AppText(language: language)
        switch phase {
        case .capture:
            return text.overlayCaptureInstruction
        case .highlight:
            if isFloatingImageEditor {
                return text.overlayFloatingInstruction
            }
            return text.overlayHighlightInstruction
        }
    }

    private var activeDragFill: Color {
        phase == .capture ? Color.white.opacity(0.06) : Color(nsColor: fillColor).opacity(opacity)
    }

    private var activeDragStroke: Color {
        phase == .capture ? .white : Color(nsColor: strokeColor)
    }

    private var activeDragStrokeWidth: CGFloat {
        phase == .capture ? 1.5 : max(CGFloat(strokeWidth), 1)
    }

    @ViewBuilder
    private func label(for rect: CGRect, color: Color) -> some View {
        Text("\(Int(rect.width)) x \(Int(rect.height))")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(color == .white ? Color.primary : color.opacity(0.95))
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
            .position(x: rect.midX, y: max(28, rect.minY - 24))
    }

    @ViewBuilder
    private func handles(for rect: CGRect, tint: Color) -> some View {
        ForEach(handlePoints(for: rect), id: \.id) { handle in
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(tint.opacity(0.88), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)
                .position(handle.point)
        }
    }

    private func animationStrokeWidth(isSelected: Bool) -> CGFloat {
        if strokeWidth > 0 {
            return CGFloat(strokeWidth) + (isSelected ? 0.5 : 0)
        }
        return isSelected ? 1.2 : 0
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragMode == nil {
                    dragMode = beginDrag(from: value.startLocation, in: size)
                }
                updateDrag(to: value.location, in: size)
            }
            .onEnded { value in
                updateDrag(to: value.location, in: size)
                finalizeDrag(in: size)
            }
    }

    private func tapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                handleTap(at: value.location, in: size)
            }
    }

    private func doubleTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                handleDoubleTap(at: value.location, in: size)
            }
    }

    private func finishSelection() {
        guard phase == .highlight, let captureRect, !animationRects.isEmpty else { return }

        let screenRect = screen.frame
        let globalRect = CGRect(
            x: screenRect.minX + captureRect.minX,
            y: screenRect.maxY - captureRect.maxY,
            width: captureRect.width,
            height: captureRect.height
        )
        let normalizedRegions = animationRects.map { rect in
            AnimationRegion(
                normalizedRect: CGRect(
                    x: (rect.minX - captureRect.minX) / captureRect.width,
                    y: (rect.minY - captureRect.minY) / captureRect.height,
                    width: rect.width / captureRect.width,
                    height: rect.height / captureRect.height
                )
            )
        }
        onFinish(
            ScreenshotOverlayController.SelectionResult(
                selection: CaptureSelection(screenFrame: screenRect, selectionRect: globalRect),
                animationRegions: normalizedRegions,
                imageOverride: frozenSelectionImage
            )
        )
    }

    private func performUndo() {
        guard let snapshot = undoStack.popLast() else { return }
        phase = snapshot.phase
        captureRect = snapshot.captureRect
        animationRects = snapshot.animationRects
        activeTarget = snapshot.activeTarget
        previewRect = nil
        dragMode = nil
        currentCursorStyle = .arrow
        applyCursorStyle(.arrow)
    }

    private func deleteActiveOrLast() {
        guard phase == .highlight else { return }
        guard captureRect != nil else { return }

        if let activeTarget {
            switch activeTarget {
            case .capture:
                guard !isFloatingImageEditor else { return }
                pushUndoSnapshot()
                captureRect = nil
                animationRects = []
                phase = .capture
                self.activeTarget = nil
            case let .animation(index):
                guard animationRects.indices.contains(index) else { return }
                pushUndoSnapshot()
                animationRects.remove(at: index)
                self.activeTarget = nil
            }
        } else if !animationRects.isEmpty {
            pushUndoSnapshot()
            _ = animationRects.popLast()
        }

        currentCursorStyle = .arrow
        applyCursorStyle(.arrow)
    }

    private func beginDrag(from startPoint: CGPoint, in size: CGSize) -> DragMode? {
        let point = clampedPoint(startPoint, within: overlayBounds(for: size))

        switch phase {
        case .capture:
            previewRect = CGRect(origin: point, size: .zero)
            currentCursorStyle = .crosshair
            applyCursorStyle(.crosshair)
            return .creatingCapture(start: point)
        case .highlight:
            if let hit = hitTest(point: point) {
                let shouldDuplicate = shouldDuplicateAnimationRect(from: hit)
                let target: EditableTarget
                let initialRect: CGRect

                if shouldDuplicate {
                    pushUndoSnapshot()
                    animationRects.append(hit.rect)
                    let duplicatedIndex = animationRects.count - 1
                    target = .animation(duplicatedIndex)
                    initialRect = animationRects[duplicatedIndex]
                    activeTarget = target
                } else {
                    activeTarget = hit.target
                    pushUndoSnapshot()
                    target = hit.target
                    initialRect = hit.rect
                }

                let cursorStyle = cursorStyle(for: hit.handle, isDragging: true)
                currentCursorStyle = cursorStyle
                applyCursorStyle(cursorStyle)
                return .editing(
                    target: target,
                    handle: hit.handle,
                    initialRect: initialRect,
                    initialCaptureRect: captureRect,
                    initialAnimationRects: animationRects,
                    start: point
                )
            }

            guard let captureRect, captureRect.contains(point) else { return nil }
            activeTarget = nil
            previewRect = CGRect(origin: point, size: .zero)
            currentCursorStyle = .crosshair
            applyCursorStyle(.crosshair)
            return .creatingAnimation(start: point)
        }
    }

    private func shouldDuplicateAnimationRect(from hit: (target: EditableTarget, handle: RectHandle, rect: CGRect)) -> Bool {
        guard case .animation = hit.target else { return false }
        guard hit.handle == .move else { return false }
        return NSEvent.modifierFlags.contains(.option)
    }

    private func updateDrag(to currentPoint: CGPoint, in size: CGSize) {
        guard let dragMode else { return }

        switch dragMode {
        case let .creatingCapture(start):
            let current = clampedPoint(currentPoint, within: overlayBounds(for: size))
            previewRect = clampRect(
                CGRect(
                    x: min(start.x, current.x),
                    y: min(start.y, current.y),
                    width: abs(current.x - start.x),
                    height: abs(current.y - start.y)
                ),
                within: overlayBounds(for: size)
            )
        case let .creatingAnimation(start):
            guard let captureRect else { return }
            let current = clampedPoint(currentPoint, within: captureRect)
            previewRect = clampRect(
                CGRect(
                    x: min(start.x, current.x),
                    y: min(start.y, current.y),
                    width: abs(current.x - start.x),
                    height: abs(current.y - start.y)
                ),
                within: captureRect
            )
        case let .editing(target, handle, initialRect, initialCaptureRect, initialAnimationRects, start):
            let current = clampedPoint(currentPoint, within: overlayBounds(for: size))
            let rect = adjustedRect(from: initialRect, handle: handle, start: start, current: current)

            switch target {
            case .capture:
                guard !isFloatingImageEditor else { return }
                let bounds = overlayBounds(for: size)
                let nextCapture = clampRect(rect, within: bounds, minimum: CGSize(width: 24, height: 24))
                captureRect = nextCapture
                if initialCaptureRect != nil {
                    animationRects = preserveAnimationRects(within: nextCapture, rects: initialAnimationRects)
                }
            case let .animation(index):
                guard let captureRect else { return }
                let nextRect = clampRect(rect, within: captureRect, minimum: CGSize(width: 12, height: 12))
                guard animationRects.indices.contains(index) else { return }
                animationRects[index] = nextRect
            }
            previewRect = nil
        }
    }

    private func finalizeDrag(in size: CGSize) {
        guard let dragMode else { return }
        defer {
            self.dragMode = nil
            previewRect = nil
        }

        switch dragMode {
        case .creatingCapture:
            guard let rect = previewRect, rect.width > 8, rect.height > 8 else { return }
            pushUndoSnapshot()
            captureRect = rect
            animationRects = []
            activeTarget = .capture
            phase = .highlight
        case .creatingAnimation:
            guard let rect = previewRect, rect.width > 8, rect.height > 8 else { return }
            pushUndoSnapshot()
            animationRects.append(rect)
            activeTarget = .animation(animationRects.count - 1)
        case .editing(let target, _, _, _, _, _):
            activeTarget = target
            if case .capture = target, captureRect == nil {
                phase = .capture
            }
        }

        refreshCursorForLastPointer(in: size)
    }

    private func pushUndoSnapshot() {
        undoStack.append(
            OverlaySnapshot(
                phase: phase,
                captureRect: captureRect,
                animationRects: animationRects,
                activeTarget: activeTarget
            )
        )
    }

    private func handleDoubleTap(at point: CGPoint, in size: CGSize) {
        guard dragMode == nil, phase == .highlight else { return }
        let point = clampedPoint(point, within: overlayBounds(for: size))

        guard let index = animationRects.indices.reversed().first(where: { animationRects[$0].contains(point) }) else {
            return
        }

        pushUndoSnapshot()
        animationRects.remove(at: index)

        if case let .animation(activeIndex)? = activeTarget {
            if activeIndex == index {
                activeTarget = nil
            } else if activeIndex > index {
                activeTarget = .animation(activeIndex - 1)
            }
        }

        refreshCursorForLastPointer(in: size)
    }

    private func handleTap(at point: CGPoint, in size: CGSize) {
        guard dragMode == nil else { return }
        let point = clampedPoint(point, within: overlayBounds(for: size))

        switch phase {
        case .capture:
            activeTarget = nil
        case .highlight:
            if let hit = hitTest(point: point) {
                activeTarget = hit.target
            } else if animationRects.indices.reversed().contains(where: { animationRects[$0].contains(point) }) {
                if let index = animationRects.indices.reversed().first(where: { animationRects[$0].contains(point) }) {
                    activeTarget = .animation(index)
                }
            } else if !isFloatingImageEditor, let captureRect, captureRect.contains(point) {
                activeTarget = .capture
            } else if let captureRect, captureRect.contains(point) {
                activeTarget = nil
            } else {
                activeTarget = nil
            }
        }

        updateCursor(at: point, in: size)
    }

    private func overlayBounds(for size: CGSize) -> CGRect {
        CGRect(origin: .zero, size: size)
    }

    private func clampedPoint(_ point: CGPoint, within bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func clampRect(_ rect: CGRect, within bounds: CGRect, minimum: CGSize = CGSize(width: 8, height: 8)) -> CGRect {
        var clamped = rect.standardized
        clamped.size.width = max(minimum.width, min(clamped.width, bounds.width))
        clamped.size.height = max(minimum.height, min(clamped.height, bounds.height))
        clamped.origin.x = min(max(clamped.origin.x, bounds.minX), bounds.maxX - clamped.width)
        clamped.origin.y = min(max(clamped.origin.y, bounds.minY), bounds.maxY - clamped.height)
        return clamped.integral
    }

    private func adjustedRect(from rect: CGRect, handle: RectHandle, start: CGPoint, current: CGPoint) -> CGRect {
        let dx = current.x - start.x
        let dy = current.y - start.y
        var next = rect

        switch handle {
        case .move:
            next.origin.x += dx
            next.origin.y += dy
        case .left:
            next.origin.x += dx
            next.size.width -= dx
        case .right:
            next.size.width += dx
        case .top:
            next.origin.y += dy
            next.size.height -= dy
        case .bottom:
            next.size.height += dy
        case .topLeft:
            next.origin.x += dx
            next.size.width -= dx
            next.origin.y += dy
            next.size.height -= dy
        case .topRight:
            next.size.width += dx
            next.origin.y += dy
            next.size.height -= dy
        case .bottomLeft:
            next.origin.x += dx
            next.size.width -= dx
            next.size.height += dy
        case .bottomRight:
            next.size.width += dx
            next.size.height += dy
        }

        return next.standardized
    }

    private func preserveAnimationRects(within captureRect: CGRect, rects: [CGRect]) -> [CGRect] {
        rects.compactMap { rect in
            let clipped = rect.intersection(captureRect).integral
            guard clipped.width > 0, clipped.height > 0 else { return nil }
            return clipped
        }
    }

    private func zoomFloatingImageEditor(deltaY: CGFloat, at point: CGPoint, in size: CGSize) {
        guard isFloatingImageEditor, phase == .highlight, dragMode == nil else { return }
        guard let currentCaptureRect = captureRect, let initialCaptureRect else { return }
        guard currentCaptureRect.width > 0, currentCaptureRect.height > 0 else { return }
        guard currentCaptureRect.insetBy(dx: -24, dy: -24).contains(point) else { return }

        floatingZoomScrollRemainder += deltaY
        let stepThreshold: CGFloat = 1
        guard abs(floatingZoomScrollRemainder) >= stepThreshold else { return }

        let direction: CGFloat = floatingZoomScrollRemainder > 0 ? 1 : -1
        floatingZoomScrollRemainder = 0

        let nextScale = min(max((floatingZoomScale + direction * 0.1).roundedToTenths, 0.25), 3.0)
        guard abs(nextScale - floatingZoomScale) > 0.001 else {
            showZoomIndicator(for: floatingZoomScale)
            return
        }

        let center = CGPoint(x: currentCaptureRect.midX, y: currentCaptureRect.midY)
        let nextSize = CGSize(
            width: initialCaptureRect.width * nextScale,
            height: initialCaptureRect.height * nextScale
        )
        let nextCaptureRect = CGRect(
            x: center.x - nextSize.width / 2,
            y: center.y - nextSize.height / 2,
            width: nextSize.width,
            height: nextSize.height
        ).integral

        let nextAnimationRects = animationRects.map { rect in
            let normalizedRect = normalizedRect(rect, in: currentCaptureRect)
            return denormalizedRect(normalizedRect, in: nextCaptureRect).integral
        }

        withAnimation(.easeOut(duration: 0.08)) {
            captureRect = nextCaptureRect
            animationRects = nextAnimationRects
            floatingZoomScale = nextScale
        }
        showZoomIndicator(for: nextScale)
        refreshCursorForLastPointer(in: size)
    }

    private func normalizedRect(_ rect: CGRect, in baseRect: CGRect) -> CGRect {
        guard baseRect.width > 0, baseRect.height > 0 else { return .zero }
        return CGRect(
            x: (rect.minX - baseRect.minX) / baseRect.width,
            y: (rect.minY - baseRect.minY) / baseRect.height,
            width: rect.width / baseRect.width,
            height: rect.height / baseRect.height
        )
    }

    private func denormalizedRect(_ rect: CGRect, in baseRect: CGRect) -> CGRect {
        CGRect(
            x: baseRect.minX + baseRect.width * rect.minX,
            y: baseRect.minY + baseRect.height * rect.minY,
            width: baseRect.width * rect.width,
            height: baseRect.height * rect.height
        )
    }

    private func showZoomIndicator(for scale: CGFloat) {
        let token = UUID()
        zoomIndicatorToken = token
        withAnimation(.easeOut(duration: 0.08)) {
            zoomIndicatorText = "\(Int((scale * 100).rounded()))%"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard zoomIndicatorToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                zoomIndicatorText = nil
            }
        }
    }

    private func hitTest(point: CGPoint) -> (target: EditableTarget, handle: RectHandle, rect: CGRect)? {
        for index in animationRects.indices.reversed() {
            let rect = animationRects[index]
            if let handle = handle(for: point, in: rect) {
                return (.animation(index), handle, rect)
            }
            if rect.contains(point) {
                return (.animation(index), .move, rect)
            }
        }

        if let captureRect, let handle = handle(for: point, in: captureRect) {
            guard !isFloatingImageEditor else { return nil }
            return (.capture, handle, captureRect)
        }

        return nil
    }

    private func updateCursor(at point: CGPoint, in size: CGSize) {
        let clamped = clampedPoint(point, within: overlayBounds(for: size))
        let style: OverlayCursorStyle

        if let dragMode {
            switch dragMode {
            case .creatingCapture, .creatingAnimation:
                style = .crosshair
            case let .editing(_, handle, _, _, _, _):
                style = cursorStyle(for: handle, isDragging: true)
            }
        } else if let hit = hitTest(point: clamped) {
            style = cursorStyle(for: hit.handle, isDragging: false)
        } else if phase == .highlight, let captureRect, captureRect.contains(clamped) {
            style = .crosshair
        } else {
            style = phase == .capture ? .crosshair : .arrow
        }

        guard style != currentCursorStyle else { return }
        currentCursorStyle = style
        applyCursorStyle(style)
    }

    private func refreshCursorForLastPointer(in size: CGSize?) {
        guard let lastPointerLocation, let size else { return }
        updateCursor(at: lastPointerLocation, in: size)
    }

    private func cursorStyle(for handle: RectHandle, isDragging: Bool) -> OverlayCursorStyle {
        switch handle {
        case .move:
            return isDragging ? .closedHand : .openHand
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .bottomRight:
            return .resizeDiagonalLeading
        case .topRight, .bottomLeft:
            return .resizeDiagonalTrailing
        }
    }

    private func applyCursorStyle(_ style: OverlayCursorStyle) {
        switch style {
        case .arrow:
            NSCursor.arrow.set()
        case .crosshair:
            NSCursor.crosshair.set()
        case .openHand:
            NSCursor.openHand.set()
        case .closedHand:
            NSCursor.closedHand.set()
        case .resizeLeftRight:
            NSCursor.resizeLeftRight.set()
        case .resizeUpDown:
            NSCursor.resizeUpDown.set()
        case .resizeDiagonalLeading:
            OverlayCursors.diagonalLeading.set()
        case .resizeDiagonalTrailing:
            OverlayCursors.diagonalTrailing.set()
        }
    }

    private func handle(for point: CGPoint, in rect: CGRect) -> RectHandle? {
        let threshold: CGFloat = 2
        let left = abs(point.x - rect.minX) <= threshold
        let right = abs(point.x - rect.maxX) <= threshold
        let top = abs(point.y - rect.minY) <= threshold
        let bottom = abs(point.y - rect.maxY) <= threshold
        let withinY = point.y >= rect.minY - threshold && point.y <= rect.maxY + threshold
        let withinX = point.x >= rect.minX - threshold && point.x <= rect.maxX + threshold

        if left && top { return .topLeft }
        if right && top { return .topRight }
        if left && bottom { return .bottomLeft }
        if right && bottom { return .bottomRight }
        if left && withinY { return .left }
        if right && withinY { return .right }
        if top && withinX { return .top }
        if bottom && withinX { return .bottom }
        return nil
    }

    private func handlePoints(for rect: CGRect) -> [(id: String, point: CGPoint)] {
        [
            ("tl", CGPoint(x: rect.minX, y: rect.minY)),
            ("t", CGPoint(x: rect.midX, y: rect.minY)),
            ("tr", CGPoint(x: rect.maxX, y: rect.minY)),
            ("r", CGPoint(x: rect.maxX, y: rect.midY)),
            ("br", CGPoint(x: rect.maxX, y: rect.maxY)),
            ("b", CGPoint(x: rect.midX, y: rect.maxY)),
            ("bl", CGPoint(x: rect.minX, y: rect.maxY)),
            ("l", CGPoint(x: rect.minX, y: rect.midY))
        ]
    }
}

private enum OverlayCursors {
    static let diagonalLeading = makeDiagonalCursor(isLeading: true)
    static let diagonalTrailing = makeDiagonalCursor(isLeading: false)

    private static func makeDiagonalCursor(isLeading: Bool) -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()

            let start = isLeading ? CGPoint(x: 5, y: 19) : CGPoint(x: 5, y: 5)
            let end = isLeading ? CGPoint(x: 19, y: 5) : CGPoint(x: 19, y: 19)
            drawLine(from: start, to: end, color: .white.withAlphaComponent(0.92), width: 5)
            drawLine(from: start, to: end, color: .black.withAlphaComponent(0.95), width: 2.2)
            drawArrowHead(at: start, toward: end, color: .white.withAlphaComponent(0.92), width: 5)
            drawArrowHead(at: end, toward: start, color: .white.withAlphaComponent(0.92), width: 5)
            drawArrowHead(at: start, toward: end, color: .black.withAlphaComponent(0.95), width: 2.2)
            drawArrowHead(at: end, toward: start, color: .black.withAlphaComponent(0.95), width: 2.2)
            return true
        }
        return NSCursor(image: image, hotSpot: CGPoint(x: 12, y: 12))
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private static func drawArrowHead(at tip: CGPoint, toward target: CGPoint, color: NSColor, width: CGFloat) {
        let dx = target.x - tip.x
        let dy = target.y - tip.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let ux = dx / length
        let uy = dy / length
        let arrowLength: CGFloat = 5.5
        let arrowSpread: CGFloat = 3.4
        let base = CGPoint(x: tip.x + ux * arrowLength, y: tip.y + uy * arrowLength)
        let perp = CGPoint(x: -uy, y: ux)

        let path = NSBezierPath()
        path.move(to: tip)
        path.line(to: CGPoint(x: base.x + perp.x * arrowSpread, y: base.y + perp.y * arrowSpread))
        path.move(to: tip)
        path.line(to: CGPoint(x: base.x - perp.x * arrowSpread, y: base.y - perp.y * arrowSpread))
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }
}

private struct PointerTrackingView: NSViewRepresentable {
    let onMove: (CGPoint) -> Void
    let onScroll: (CGFloat, CGPoint) -> Void
    let onRightClick: () -> Void
    let onExit: () -> Void

    func makeNSView(context: Context) -> PointerTrackingNSView {
        let view = PointerTrackingNSView()
        view.onMove = onMove
        view.onScroll = onScroll
        view.onRightClick = onRightClick
        view.onExit = onExit
        return view
    }

    func updateNSView(_ nsView: PointerTrackingNSView, context: Context) {
        nsView.onMove = onMove
        nsView.onScroll = onScroll
        nsView.onRightClick = onRightClick
        nsView.onExit = onExit
    }
}

private final class PointerTrackingNSView: NSView {
    var onMove: ((CGPoint) -> Void)?
    var onScroll: ((CGFloat, CGPoint) -> Void)?
    var onRightClick: (() -> Void)?
    var onExit: (() -> Void)?
    private var trackingAreaRef: NSTrackingArea?
    private var scrollMonitor: Any?

    override var isFlipped: Bool { true }

    deinit {
        removeScrollMonitor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeScrollMonitor()
        } else {
            installScrollMonitor()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMove?(point)
    }

    override func mouseExited(with event: NSEvent) {
        onExit?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func scrollWheel(with event: NSEvent) {
        handleScrollEvent(event)
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        guard event.window === window else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }

        let dominantDelta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
            ? event.scrollingDeltaY
            : -event.scrollingDeltaX
        guard dominantDelta != 0 else { return }
        onScroll?(dominantDelta, point)
    }
}

private struct KeyCatcherView: NSViewRepresentable {
    let onEscape: () -> Void
    let onConfirm: () -> Void
    let onUndo: () -> Void
    let onDeleteLast: () -> Void

    func makeNSView(context: Context) -> KeyCatcherNSView {
        let view = KeyCatcherNSView()
        view.onEscape = onEscape
        view.onConfirm = onConfirm
        view.onUndo = onUndo
        view.onDeleteLast = onDeleteLast
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCatcherNSView, context: Context) {
        nsView.onEscape = onEscape
        nsView.onConfirm = onConfirm
        nsView.onUndo = onUndo
        nsView.onDeleteLast = onDeleteLast
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private extension CGFloat {
    var roundedToTenths: CGFloat {
        (self * 10).rounded() / 10
    }
}

private final class KeyCatcherNSView: NSView {
    var onEscape: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onUndo: (() -> Void)?
    var onDeleteLast: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
        } else if event.keyCode == 36 || event.keyCode == 76 {
            onConfirm?()
        } else if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "z" {
            onUndo?()
        } else if event.keyCode == 51 || event.keyCode == 117 {
            onDeleteLast?()
        } else {
            super.keyDown(with: event)
        }
    }
}
