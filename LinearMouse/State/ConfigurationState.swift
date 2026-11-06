// MIT License
// Copyright (c) 2021-2026 LinearMouse

import AppKit
import Combine
import Defaults
import Foundation
import os.log
import SwiftUI

class ConfigurationState: ObservableObject {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

    static let shared = ConfigurationState()

    #if DEBUG
        private static let testConfigurationURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("linearmouse-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("linearmouse.json")
    #endif

    var configurationPaths: [URL] {
        #if DEBUG
            if ProcessEnvironment.isRunningTest {
                return [Self.testConfigurationURL]
            }
        #endif

        var urls: [URL] = []

        if let applicationSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first {
            urls.append(
                URL(
                    fileURLWithPath: "mac-utils/mouse.json",
                    relativeTo: applicationSupportURL
                )
            )
        }

        urls.append(
            URL(
                fileURLWithPath: ".config/mac-utils/mouse.json",
                relativeTo: FileManager.default.homeDirectoryForCurrentUser
            )
        )

        return urls
    }

    /// Files written by a standalone LinearMouse install, imported once on first launch.
    private var legacyConfigurationPaths: [URL] {
        var urls: [URL] = []
        if let applicationSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first {
            urls.append(applicationSupportURL.appendingPathComponent("linearmouse/linearmouse.json"))
        }
        urls.append(
            FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent(".config/linearmouse/linearmouse.json")
        )
        return urls
    }

    private func importLegacyConfigurationIfNeeded() {
        #if DEBUG
            if ProcessEnvironment.isRunningTest {
                return
            }
        #endif

        let fileManager = FileManager.default
        guard !configurationPaths.contains(where: { fileManager.fileExists(atPath: $0.path) }),
              let legacyURL = legacyConfigurationPaths.first(where: { fileManager.fileExists(atPath: $0.path) })
        else {
            return
        }

        do {
            try Self.importConfiguration(from: legacyURL, to: configurationPath)
        } catch {
            os_log(
                "Failed to import LinearMouse configuration: %{public}@",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    /// Copies the file's contents, not the file itself: a dotfiles symlink must not be carried over, or saving
    /// MacUtils settings would rewrite the LinearMouse configuration it points to.
    static func importConfiguration(from source: URL, to destination: URL) throws {
        let data = try Data(contentsOf: source.resolvingSymlinksInPath())
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .withoutOverwriting)
    }

    var configurationPath: URL {
        configurationPaths.first { FileManager.default.fileExists(atPath: $0.path) } ?? configurationPaths
            .last!
    }

    private var configurationSaveDebounceTimer: Timer?
    @Published var configuration = Configuration() {
        didSet {
            configurationSaveDebounceTimer?.invalidate()
            guard !loading, ProcessEnvironment.isRunningApp else {
                return
            }

            configurationSaveDebounceTimer = Timer.scheduledTimer(
                withTimeInterval: 0.2,
                repeats: false
            ) { [weak self] _ in
                guard let self else {
                    return
                }

                os_log(
                    "Saving new configuration: %{public}@",
                    log: Self.log,
                    type: .info,
                    String(describing: self.configuration)
                )
                self.save()
            }
        }
    }

    @Published private(set) var loading = false

    private var subscriptions = Set<AnyCancellable>()

    private var configurationFileWatcher: FileWatcher?
    private var reloadDebounceWorkItem: DispatchWorkItem?
}

extension ConfigurationState {
    func reloadFromDisk() {
        do {
            let newConfig = try Configuration.load(from: configurationPath)
            guard newConfig != configuration else {
                return
            }

            loading = true
            configuration = newConfig
            loading = false

            Notifier.shared.notify(
                title: NSLocalizedString("Configuration Reloaded", comment: ""),
                body: NSLocalizedString("Your configuration changes are now active.", comment: "")
            )
        } catch CocoaError.fileReadNoSuchFile {
            loading = true
            configuration = .init()
            loading = false

            Notifier.shared.notify(
                title: NSLocalizedString("Configuration Reloaded", comment: ""),
                body: NSLocalizedString("Your configuration changes are now active.", comment: "")
            )
        } catch {
            Notifier.shared.notify(
                title: NSLocalizedString("Failed to reload configuration", comment: ""),
                body: error.localizedDescription
            )
        }
    }

    func startHotReload() {
        stopHotReload()

        configurationFileWatcher = FileWatcher(
            fileURLsProvider: { [weak self] in
                self?.configurationPaths ?? []
            },
            queue: .main
        ) { [weak self] in
            self?.scheduleReloadFromExternalChange()
        }
        configurationFileWatcher?.start()
    }

    func stopHotReload() {
        reloadDebounceWorkItem?.cancel()
        reloadDebounceWorkItem = nil

        configurationFileWatcher?.stop()
        configurationFileWatcher = nil
    }

    private func scheduleReloadFromExternalChange() {
        reloadDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadFromDisk()
        }
        reloadDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.shared.configurationPath.absoluteURL])
    }

    func load() {
        loading = true
        defer {
            loading = false
        }

        importLegacyConfigurationIfNeeded()

        do {
            configuration = try Configuration.load(from: configurationPath)
            // Publish migration only after its backup and atomic write succeed.
            do {
                try configuration.migrateLegacyGestureButtons(persistingTo: configurationPath)
            } catch {
                os_log(
                    "Gesture migration failed: %{public}@",
                    log: Self.log,
                    type: .error,
                    error.localizedDescription
                )
            }
        } catch CocoaError.fileReadNoSuchFile {
            os_log(
                "No configuration file found, try creating a default one",
                log: Self.log,
                type: .info
            )
            save()
        } catch {
            let alert = NSAlert()
            alert.messageText = String(
                format: NSLocalizedString("Failed to load the configuration: %@", comment: ""),
                error.localizedDescription
            )
            alert.runModal()
        }
    }

    func save() {
        guard ProcessEnvironment.isRunningApp else {
            return
        }

        do {
            try configuration.dump(to: configurationPath)
        } catch {
            let alert = NSAlert()
            alert.messageText = String(
                format: NSLocalizedString("Failed to save the configuration: %@", comment: ""),
                error.localizedDescription
            )
            alert.runModal()
        }
    }
}
