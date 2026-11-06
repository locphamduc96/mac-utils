// MIT License
// Copyright (c) 2026 MacUtils
// Layout math adapted from Rectangle (https://github.com/rxhanson/Rectangle), MIT License.

import CoreGraphics

enum WindowLayoutAction: String, CaseIterable {
    case almostMaximize
    case centerTwoThirds

    var title: String {
        switch self {
        case .almostMaximize:
            return "Gần toàn màn hình"
        case .centerTwoThirds:
            return "Giữa, rộng 2/3"
        }
    }

    var detail: String {
        switch self {
        case .almostMaximize:
            return "Cửa sổ chiếm 90% vùng làm việc, đặt ở giữa."
        case .centerTwoThirds:
            return "Cửa sổ rộng 2/3 vùng làm việc, cao hết cỡ, đặt ở giữa. Màn hình dọc thì chia theo chiều cao."
        }
    }
}

enum WindowLayout {
    static let almostMaximizeRatio: CGFloat = 0.9

    /// Target frame in AppKit coordinates (origin bottom-left), inside `visibleFrame`.
    static func frame(for action: WindowLayoutAction, in visibleFrame: CGRect) -> CGRect {
        switch action {
        case .almostMaximize:
            let width = round(visibleFrame.width * almostMaximizeRatio)
            let height = round(visibleFrame.height * almostMaximizeRatio)
            return CGRect(
                x: visibleFrame.minX + round((visibleFrame.width - width) / 2),
                y: visibleFrame.minY + round((visibleFrame.height - height) / 2),
                width: width,
                height: height
            )
        case .centerTwoThirds:
            if visibleFrame.width > visibleFrame.height {
                return CGRect(
                    x: visibleFrame.minX + floor(visibleFrame.width / 3) / 2,
                    y: visibleFrame.minY,
                    width: visibleFrame.width / 3 * 2,
                    height: visibleFrame.height
                )
            }
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY + floor(visibleFrame.height / 3) / 2,
                width: visibleFrame.width,
                height: visibleFrame.height / 3 * 2
            )
        }
    }

    /// Index of the screen sharing the largest area with `windowFrame`; nil when it overlaps none.
    static func screenIndex(for windowFrame: CGRect, screenFrames: [CGRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, screenFrame) in screenFrames.enumerated() {
            let overlap = screenFrame.intersection(windowFrame)
            guard !overlap.isNull else {
                continue
            }
            let area = overlap.width * overlap.height
            if area > (best?.area ?? 0) {
                best = (index, area)
            }
        }
        return best?.index
    }

    /// Converts between AppKit (bottom-left origin) and Accessibility (top-left origin) coordinates.
    /// The conversion is its own inverse.
    static func flipped(_ rect: CGRect, primaryScreenMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenMaxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
