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
        observations.append(Defaults.observe(keys: .vietnameseModuleEnabled, .vietnameseTypingOn) { [weak self] in
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
        item.button?.attributedTitle = NSAttributedString(
            string: on ? "V" : "E",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: on ? NSColor.controlAccentColor : NSColor.labelColor
            ]
        )
        item.button?.toolTip = on ? "Đang gõ tiếng Việt (⌃⇧ để tắt)" : "Đang gõ tiếng Anh (⌃⇧ để bật)"
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

        let toggle = NSMenuItem(title: "Gõ tiếng Việt  (⌃⇧)", action: #selector(toggleTyping), keyEquivalent: "")
        toggle.target = self
        toggle.state = Defaults[.vietnameseTypingOn] ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        let current = Defaults[.vietnameseInputMethod]
        for method in VietnameseInputMethod.allCases {
            let item = NSMenuItem(title: method.title, action: #selector(selectInputMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = method.rawValue
            item.state = method == current ? .on : .off
            menu.addItem(item)
        }
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

    @objc private func openSettings() {
        SettingsWindowController.shared.bringToFront()
    }
}
