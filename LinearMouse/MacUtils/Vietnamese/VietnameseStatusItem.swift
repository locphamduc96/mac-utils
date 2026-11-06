// MIT License
// Copyright (c) 2026 MacUtils

import AppKit
import Defaults
import LaunchAtLogin

/// Separate menu bar item showing V / E, so the typing state is visible at a glance.
final class VietnameseStatusItem: NSObject, NSMenuDelegate {
    static let shared = VietnameseStatusItem()

    private var statusItem: NSStatusItem?
    private var observations: [Defaults.Observation] = []

    func start() {
        guard observations.isEmpty else {
            return
        }
        observations.append(Defaults.observe(
            keys: .vietnameseModuleEnabled,
            .vietnameseTypingOn,
            .vietnameseToggleHotkey
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.update()
            }
        })
    }

    func stop() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func update() {
        guard Defaults[.vietnameseModuleEnabled] else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
            return
        }

        let item = statusItem ?? makeStatusItem()
        statusItem = item
        let on = Defaults[.vietnameseTypingOn]
        let hotkey = Defaults[.vietnameseToggleHotkey].shortTitle
        item.button?.image = Self.outlinedLetter(on ? "V" : "E")
        item.button?.toolTip = on ? "Đang gõ tiếng Việt (\(hotkey) để tắt)" : "Đang gõ tiếng Anh (\(hotkey) để bật)"
    }

    /// Hollow letter (outline only) as a template image, so the menu bar draws it white or black to match.
    static func outlinedLetter(_ letter: String) -> NSImage {
        let text = NSAttributedString(
            string: letter,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .bold),
                .strokeColor: NSColor.black,
                // A positive stroke width draws the outline without filling the glyph.
                .strokeWidth: 4.5
            ]
        )
        let textSize = text.size()
        let size = NSSize(width: ceil(textSize.width) + 2, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            text.draw(at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(
            title: "Gõ tiếng Việt  (\(Defaults[.vietnameseToggleHotkey].shortTitle))",
            action: #selector(toggleTyping),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = Defaults[.vietnameseTypingOn] ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        let currentMode = Defaults[.vietnameseTypingMode]
        for mode in VietnameseTypingMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectTypingMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentMode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let current = Defaults[.vietnameseInputMethod]
        for method in VietnameseInputMethod.allCases {
            let item = NSMenuItem(title: method.title, action: #selector(selectInputMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = method.rawValue
            item.state = method == current ? .on : .off
            menu.addItem(item)
        }

        let codeTableMenu = NSMenu()
        let currentTable = Defaults[.vietnameseCodeTable]
        for table in VietCodeTable.allCases {
            let item = NSMenuItem(title: table.title, action: #selector(selectCodeTable(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = table.rawValue
            item.state = table == currentTable ? .on : .off
            codeTableMenu.addItem(item)
        }
        let codeTableItem = NSMenuItem(title: "Bảng mã: \(currentTable.title)", action: nil, keyEquivalent: "")
        codeTableItem.submenu = codeTableMenu
        menu.addItem(codeTableItem)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Cài đặt MacUtils…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let startAtLogin = NSMenuItem(
            title: "Mở lúc khởi động",
            action: #selector(toggleStartAtLogin),
            keyEquivalent: ""
        )
        startAtLogin.target = self
        startAtLogin.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(startAtLogin)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Thoát MacUtils", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleStartAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func toggleTyping() {
        Defaults[.vietnameseTypingOn].toggle()
    }

    @objc private func selectInputMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let method = VietnameseInputMethod(rawValue: raw)
        else {
            return
        }
        Defaults[.vietnameseInputMethod] = method
    }

    @objc private func selectTypingMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = VietnameseTypingMode(rawValue: raw) else {
            return
        }
        Defaults[.vietnameseTypingMode] = mode
    }

    @objc private func selectCodeTable(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let table = VietCodeTable(rawValue: raw) else {
            return
        }
        Defaults[.vietnameseCodeTable] = table
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.bringToFront()
    }
}
