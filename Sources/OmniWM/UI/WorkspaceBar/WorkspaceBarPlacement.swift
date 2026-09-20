// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit

enum WorkspaceBarWindowLevel: String, CaseIterable, Codable, Identifiable {
    case normal
    case floating
    case status
    case popup
    case screensaver

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .normal: "Normal"
        case .floating: "Floating"
        case .status: "Status Bar"
        case .popup: "Popup"
        case .screensaver: "Screen Saver"
        }
    }

    var nsWindowLevel: NSWindow.Level {
        switch self {
        case .normal: .normal
        case .floating: .floating
        case .status: .statusBar
        case .popup: .popUpMenu
        case .screensaver: .screenSaver
        }
    }
}

enum WorkspaceBarPosition: String, CaseIterable, Codable, Identifiable {
    case overlappingMenuBar
    case belowMenuBar
    case bottom
    case left
    case right

    var isVertical: Bool {
        self == .left || self == .right
    }

    var usesNotch: Bool {
        self == .overlappingMenuBar || self == .belowMenuBar
    }

    var popupEdge: PopupAttachment.Edge {
        switch self {
        case .overlappingMenuBar,
             .belowMenuBar: .below
        case .bottom: .above
        case .left: .right
        case .right: .left
        }
    }

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .overlappingMenuBar: "Overlapping Menu Bar"
        case .belowMenuBar: "Below Menu Bar"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

enum WorkspaceBarNotchMode: String, CaseIterable, Codable, Identifiable {
    case off
    case moveBelowMenuBar
    case splitActiveLeft
    case splitActiveRight
    case fillLeftOfNotch

    var id: String {
        rawValue
    }

    var isSplit: Bool {
        self == .splitActiveLeft || self == .splitActiveRight
    }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .moveBelowMenuBar: "Move Below Menu Bar"
        case .splitActiveLeft: "Split — Active Left"
        case .splitActiveRight: "Split — Active Right"
        case .fillLeftOfNotch: "Fill Left of Notch"
        }
    }
}
