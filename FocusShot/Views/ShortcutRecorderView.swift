import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (HotKeyShortcut) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((HotKeyShortcut) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let shortcut = HotKeyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard shortcut.isValid else { return }
        onCapture?(shortcut)
    }
}
