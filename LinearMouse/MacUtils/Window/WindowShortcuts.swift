// MIT License
// Copyright (c) 2026 MacUtils

import Combine
import Defaults

extension Defaults.Keys {
    static let windowShortcutsEnabled = Key<Bool>("macUtils.windowShortcutsEnabled", default: true)
}

final class WindowShortcuts: ObservableObject {
    static let shared = WindowShortcuts()

    static let bindings: [(action: WindowLayoutAction, combo: HotKeyCombo)] = [
        (.almostMaximize, .controlOptionC),
        (.centerTwoThirds, .controlOptionX)
    ]

    @Published private(set) var failedCombos: [String] = []

    private var running = false
    private var enabledObservation: Defaults.Observation?

    func start() {
        guard !running else {
            return
        }
        running = true
        apply(enabled: Defaults[.windowShortcutsEnabled])
        enabledObservation = Defaults.observe(.windowShortcutsEnabled, options: []) { [weak self] change in
            DispatchQueue.main.async {
                guard let self, self.running else {
                    return
                }
                self.apply(enabled: change.newValue)
            }
        }
    }

    func stop() {
        running = false
        enabledObservation?.invalidate()
        enabledObservation = nil
        apply(enabled: false)
    }

    private func apply(enabled: Bool) {
        let hotKeys = GlobalHotKeys.shared
        hotKeys.unregisterAll()
        if enabled {
            for binding in Self.bindings {
                hotKeys.register(binding.combo) {
                    WindowMover.perform(binding.action)
                }
            }
        }
        failedCombos = hotKeys.failedCombos
    }
}
