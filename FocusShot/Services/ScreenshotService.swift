import AppKit
import Foundation

struct ScreenshotService {
    func captureImage(for selection: CaptureSelection) -> NSImage? {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusshot-\(UUID().uuidString)")
            .appendingPathExtension("png")

        let rect = selection.topLeftRect.integral
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x",
            "-R\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))",
            temporaryURL.path
        ]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        return NSImage(contentsOf: temporaryURL)
    }

    func captureScreenImage(for screen: NSScreen) -> NSImage? {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusshot-screen-\(UUID().uuidString)")
            .appendingPathExtension("png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        if let displayIndex = NSScreen.screens.firstIndex(of: screen) {
            process.arguments = ["-x", "-D", "\(displayIndex + 1)", temporaryURL.path]
        } else {
            process.arguments = ["-x", temporaryURL.path]
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        return NSImage(contentsOf: temporaryURL)
    }
}
