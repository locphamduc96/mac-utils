// MIT License
// Copyright (c) 2026 MacUtils

@testable import LinearMouse
import XCTest

final class WindowLayoutTests: XCTestCase {
    /// 1512×982 MacBook screen minus a 37 pt menu bar.
    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 945)

    func testAlmostMaximizeIsNinetyPercentCentered() {
        let frame = WindowLayout.frame(for: .almostMaximize, in: laptop)
        XCTAssertEqual(frame, CGRect(x: 76, y: 47, width: 1361, height: 851))
        XCTAssertEqual(frame.midX, laptop.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, laptop.midY, accuracy: 1)
    }

    func testAlmostMaximizeOnOffsetScreen() {
        let external = CGRect(x: 1512, y: -200, width: 2560, height: 1415)
        let frame = WindowLayout.frame(for: .almostMaximize, in: external)
        XCTAssertTrue(external.contains(frame))
        XCTAssertEqual(frame.width, 2304)
        XCTAssertEqual(frame.height, 1274)
        XCTAssertEqual(frame.midX, external.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, external.midY, accuracy: 1)
    }

    func testCenterTwoThirdsLandscapeKeepsFullHeight() {
        let frame = WindowLayout.frame(for: .centerTwoThirds, in: laptop)
        XCTAssertEqual(frame.width, 1008)
        XCTAssertEqual(frame.height, laptop.height)
        XCTAssertEqual(frame.minY, laptop.minY)
        XCTAssertEqual(frame.minX, 252)
        XCTAssertEqual(frame.midX, laptop.midX, accuracy: 1)
    }

    func testCenterTwoThirdsPortraitSplitsHeight() {
        let portrait = CGRect(x: -1080, y: 0, width: 1080, height: 1895)
        let frame = WindowLayout.frame(for: .centerTwoThirds, in: portrait)
        XCTAssertEqual(frame.width, portrait.width)
        XCTAssertEqual(frame.minX, portrait.minX)
        XCTAssertEqual(frame.height, 1895.0 / 3 * 2, accuracy: 0.001)
        XCTAssertEqual(frame.midY, portrait.midY, accuracy: 1)
    }

    func testScreenIndexPicksLargestOverlap() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1512, height: 982),
            CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        ]
        let mostlyOnSecond = CGRect(x: 1400, y: 100, width: 800, height: 600)
        XCTAssertEqual(WindowLayout.screenIndex(for: mostlyOnSecond, screenFrames: screens), 1)
        let mostlyOnFirst = CGRect(x: 1000, y: 100, width: 800, height: 600)
        XCTAssertEqual(WindowLayout.screenIndex(for: mostlyOnFirst, screenFrames: screens), 0)
        let offScreen = CGRect(x: 9000, y: 9000, width: 10, height: 10)
        XCTAssertNil(WindowLayout.screenIndex(for: offScreen, screenFrames: screens))
    }

    func testFlipRoundTripsBetweenAppKitAndAccessibility() {
        let appKit = CGRect(x: 76, y: 47, width: 1361, height: 851)
        let accessibility = WindowLayout.flipped(appKit, primaryScreenMaxY: 982)
        XCTAssertEqual(accessibility, CGRect(x: 76, y: 84, width: 1361, height: 851))
        XCTAssertEqual(WindowLayout.flipped(accessibility, primaryScreenMaxY: 982), appKit)
    }
}
