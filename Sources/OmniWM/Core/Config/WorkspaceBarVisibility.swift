// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation

enum WorkspaceBarVisibility: String, CaseIterable, Codable, Identifiable {
    case alwaysVisible
    case temporary

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .alwaysVisible: "Always Visible"
        case .temporary: "Show Temporarily"
        }
    }
}
