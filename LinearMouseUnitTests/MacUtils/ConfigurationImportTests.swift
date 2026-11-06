// MIT License
// Copyright (c) 2026 MacUtils

@testable import LinearMouse
import XCTest

final class ConfigurationImportTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("macutils-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testImportOfSymlinkedLegacyConfigWritesIndependentFile() throws {
        let dotfile = directory.appendingPathComponent("dotfiles/linearmouse.json")
        try FileManager.default.createDirectory(
            at: dotfile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"schemes":[]}"#.utf8).write(to: dotfile)
        let legacy = directory.appendingPathComponent("legacy/linearmouse.json")
        try FileManager.default.createDirectory(
            at: legacy.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: legacy, withDestinationURL: dotfile)

        let destination = directory.appendingPathComponent("mac-utils/mouse.json")
        try ConfigurationState.importConfiguration(from: legacy, to: destination)

        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeRegular)
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: dotfile))

        try Data(#"{"schemes":[{}]}"#.utf8).write(to: destination)
        XCTAssertEqual(try String(contentsOf: dotfile, encoding: .utf8), #"{"schemes":[]}"#)
    }
}
