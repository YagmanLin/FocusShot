# FocusShot

[English](./README.md) | [简体中文](./README.zh-CN.md)

FocusShot is a macOS screenshot tool designed for quickly creating highlight-style rectangle animations.

Instead of forcing you into a separate editor or timeline after taking a screenshot, FocusShot lets you keep drawing one or more rectangles directly on the capture overlay, automatically turns them into left-to-right reveal animations, and exports the result as an MP4.

## Features

- Draw highlight rectangles directly on the same overlay after taking a screenshot, without switching to an intermediate preview screen
- Draw multiple rectangles and play them in the exact order they were created
- Use a left-to-right clipping reveal animation instead of a simple fade-in
- Keep preview and export perfectly aligned by using the same animation pipeline
- Customize total duration, opacity, stroke width, stroke color, and fill color
- Support multiple blend modes
- Choose between per-rectangle easing and shared sequence easing
- Adjust easing with a curve editor by dragging control points directly
- Move, resize, double-click to delete, and `Option + Drag` to duplicate rectangles
- Undo with `Command + Z`
- Double-click the preview to jump back into rectangle editing
- Drag images into the preview for annotation, or paste images from the clipboard
- Export to MP4 with timestamp-based default filenames
- Support custom screenshot shortcuts and a fixed export shortcut with `Command + E`
- Support menu bar mode, showing the main window, launch at login, and language switching

## Use Cases

- Highlight animations for key sentences in articles
- Local emphasis in tutorial videos
- App UI walkthroughs and demonstrations
- Annotating important parts of papers, webpages, and screenshots
- “Highlight this part” visual effects for short-form social media videos

## Workflow

1. Open FocusShot and click “Start Capture” or use the screenshot shortcut.
2. Drag to select the capture area.
3. Draw one or more rectangles on the same capture overlay.
4. Press `Enter` to finish and update the preview.
5. Press `Command + E` or click the export button to render an MP4.

## Interaction Highlights

- Double-click the preview to return to editing
- Zoom the image with the mouse wheel while editing
- Select, move, and resize existing rectangles directly
- Use `Option + Drag` to duplicate a rectangle
- Double-click a rectangle to delete it quickly
- A shortcut hint card appears in the lower-left corner and hides automatically when the selection overlaps it

## Shortcuts

- Screenshot: default `Option + W`
- Export video: `Command + E`
- Finish current capture/edit: `Enter`
- Cancel capture: `Esc`
- Undo: `Command + Z`

The screenshot shortcut can be customized in the app, while the export shortcut remains fixed as `Command + E`.

## Tech Stack

- Platform: macOS
- Language: Swift
- UI: SwiftUI + AppKit
- Export: AVFoundation
- Hotkeys: Carbon HotKey / AppKit event bridging

The project follows a lightweight utility app structure: the main window handles controls and preview, the overlay handles region selection and rectangle editing, and the export module renders static captures plus highlight animations into video.

## Development

### Requirements

- Xcode
- macOS

### Run Locally

```bash
cd /Users/wxc/Coding/FocusShot
xcodebuild -project /Users/wxc/Coding/FocusShot/FocusShot.xcodeproj -scheme FocusShot -configuration Debug build
```

You can also open the project directly in Xcode:

- `/Users/wxc/Coding/FocusShot/FocusShot.xcodeproj`

Then select the `FocusShot` scheme and run it.

## Permissions

As a screenshot tool, the app usually needs these permissions on first launch:

- Screen Recording
- Accessibility permission in some cases

Without the required permissions, captures may come out blank or fail to record screen content correctly.

## Packaging & Release

The repository already includes packaging scripts and release notes:

- Release notes: [RELEASE.md](./RELEASE.md)
- Packaging script: `Scripts/package_release.sh`

If you only run it locally, normal Xcode development signing is enough.

If you want to distribute it to other users, it is recommended to add:

- Developer ID signing
- notarization
- DMG distribution

## Project Structure

```text
FocusShot/
├─ FocusShot/                # App source code
├─ FocusShot.xcodeproj       # Xcode project
├─ Scripts/                  # Packaging and utility scripts
├─ logo/                     # Icons and visual assets
├─ dist/                     # Build and release output
└─ RELEASE.md                # Release notes
```

## Current Status

FocusShot already has a full usable workflow:

- Capture
- Draw multiple rectangles
- Tune timing and styling
- Live preview
- Re-edit
- Export MP4

It is more of a focused utility built around one very specific need, highlight animation for screenshots, rather than a generic screenshot app.

## License

If you plan to publish the repository, consider adding a proper license such as the MIT License.
