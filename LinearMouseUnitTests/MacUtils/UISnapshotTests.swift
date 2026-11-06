// MIT License
// Copyright (c) 2026 MacUtils

@testable import LinearMouse
import SwiftUI
import XCTest

/// Renders every settings page to PNG for UI review. Skipped unless the output directory is given:
/// `TEST_RUNNER_MACUTILS_SNAPSHOT_DIR=/abs/dir xcodebuild test ... -only-testing:LinearMouseUnitTests/UISnapshotTests`
final class UISnapshotTests: XCTestCase {
    private var outputDirectory: URL!

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["MACUTILS_SNAPSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("MACUTILS_SNAPSHOT_DIR not set")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func testRenderSettingsPages() throws {
        let controller = SettingsWindowController.shared
        controller.bringToFront()
        NSApp.activate(ignoringOtherApps: true)
        settle()
        // The test host never starts DeviceManager, and DeviceState resets the matcher on its first
        // debounced update; set the "all mice" scheme after that so device pages render.
        DeviceState.shared.currentDeviceMatcher = DeviceMatcher(category: .mouse)
        let window = try XCTUnwrap(controller.window)

        let listPages: [(String, SettingsState.Navigation, [SettingsState.ButtonsDestination])] = [
            ("01-con-tro", .pointer, []),
            ("02-cuon", .scrolling, []),
            ("03-nut", .buttons, []),
            ("03b-nut-gan-phim", .buttons, [.buttonMappings]),
            ("03c-nut-tu-cuon", .buttons, [.autoScroll]),
            ("04-cua-so", .window, []),
            ("05-tieng-viet", .vietnamese, []),
            ("06-chung", .general, [])
        ]
        for (name, navigation, path) in listPages {
            SettingsState.shared.navigation = navigation
            selectSidebarRow(for: navigation, in: window)
            settle()
            // Replacing the detail view clears the buttons path on disappear, so set it afterwards.
            SettingsState.shared.buttonsNavigationPath = path
            settle()
            window.toolbar?.validateVisibleItems()
            settle()
            try save(window: window, name: name)
        }
        controller.close()

        let permission = NSHostingView(rootView: AccessibilityPermissionView())
        permission.frame = NSRect(x: 0, y: 0, width: 440, height: 260)
        let permissionWindow = NSWindow(
            contentRect: permission.frame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        permissionWindow.isReleasedWhenClosed = false
        permissionWindow.contentView = permission
        permissionWindow.makeKeyAndOrderFront(nil)
        settle()
        try save(window: permissionWindow, name: "07-xin-quyen-accessibility")
        permissionWindow.close()

        try saveMenuBarIcons(name: "08-icon-thanh-menu")
    }

    /// V / E template icons tinted as the menu bar does, on a dark and a light bar, at 4×.
    private func saveMenuBarIcons(name: String) throws {
        let scale: CGFloat = 4
        let bar = NSSize(width: 120, height: 24)
        let canvas = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bar.width * scale),
            pixelsHigh: Int(bar.height * 2 * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        canvas.size = NSSize(width: bar.width, height: bar.height * 2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
        for (row, background, tint) in [(1, NSColor(white: 0.12, alpha: 1), NSColor.white), (0, .white, .black)] {
            let barRect = NSRect(x: 0, y: CGFloat(row) * bar.height, width: bar.width, height: bar.height)
            background.setFill()
            barRect.fill()
            for (index, letter) in ["V", "E"].enumerated() {
                let icon = VietnameseStatusItem.outlinedLetter(letter)
                let tinted = NSImage(size: icon.size, flipped: false) { rect in
                    icon.draw(in: rect)
                    tint.set()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                let origin = NSPoint(x: 30 + CGFloat(index) * 40, y: barRect.minY + (bar.height - icon.size.height) / 2)
                tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let data = try XCTUnwrap(canvas.representation(using: .png, properties: [:]))
        try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
    }

    /// The theme frame (content view's superview) includes the title bar and toolbar.
    /// `cacheDisplay` skips the vibrant sidebar, so its rows are drawn separately over an opaque
    /// window background.
    private func save(window: NSWindow, name: String) throws {
        let root = try XCTUnwrap(window.contentView?.superview ?? window.contentView)
        root.layoutSubtreeIfNeeded()
        let base = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
        root.cacheDisplay(in: root.bounds, to: base)

        let canvas = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: base.pixelsWide,
            pixelsHigh: base.pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        canvas.size = root.bounds.size
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: canvas))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            root.bounds.fill()
            draw(base, in: root.bounds)
            let sidebar = (window.contentViewController as? NSSplitViewController)?.splitViewItems
                .first?
                .viewController
                .view
            let tableView = sidebar.map(descendants(of:))?.compactMap { $0 as? NSTableView }.first
            for row in 0 ..< (tableView?.numberOfRows ?? 0) {
                guard let rowView = tableView?.rowView(atRow: row, makeIfNecessary: true) else {
                    continue
                }
                // Row (selection) first, then the cell's icon and label.
                let listViews = [rowView] + descendants(of: rowView).filter { $0.superview is NSTableCellView }
                for view in listViews {
                    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        continue
                    }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    var rect = view.convert(view.bounds, to: root)
                    if root.isFlipped {
                        rect.origin.y = root.bounds.height - rect.maxY
                    }
                    draw(rep, in: rect)
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let data = try XCTUnwrap(canvas.representation(using: .png, properties: [:]))
        try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }

    /// Setting the navigation in code leaves the sidebar highlight where it was.
    private func selectSidebarRow(for navigation: SettingsState.Navigation, in window: NSWindow) {
        let sidebar = (window.contentViewController as? NSSplitViewController)?.splitViewItems
            .first?
            .viewController
            .view
        let tableView = sidebar.map(descendants(of:))?.compactMap { $0 as? NSTableView }.first
        if let index = SettingsState.Navigation.allCases.firstIndex(of: navigation) {
            tableView?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
    }

    /// `NSImageRep.draw(in:)` copies, wiping what is below; composite instead.
    private func draw(_ rep: NSImageRep, in rect: NSRect) {
        rep.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }
}
