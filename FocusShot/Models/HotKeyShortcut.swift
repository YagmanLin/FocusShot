import AppKit
import Carbon
import Foundation

struct HotKeyShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiersRawValue: UInt

    static let `default` = HotKeyShortcut(keyCode: 13, modifiers: [.option])

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayString: String {
        let symbols: [(NSEvent.ModifierFlags, String)] = [
            (.control, "⌃"),
            (.option, "⌥"),
            (.shift, "⇧"),
            (.command, "⌘")
        ]
        let modifierText = symbols
            .filter { modifiers.contains($0.0) }
            .map(\.1)
            .joined()

        return modifierText + keyDisplay
    }

    var isValid: Bool {
        !modifiers.intersection([.command, .option, .control, .shift]).isEmpty
    }

    private var keyDisplay: String {
        HotKeyShortcut.keyMap[Int(keyCode)] ?? "Key \(keyCode)"
    }

    private static let keyMap: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        49: "Space", 50: "`", 65: ".", 67: "*", 69: "+", 71: "Clear", 75: "/", 76: "Enter",
        78: "-", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6",
        89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 109: "F10", 111: "F12", 114: "Help", 115: "Home", 116: "PgUp",
        117: "Delete", 118: "F4", 119: "End", 120: "F2", 121: "PgDn", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
