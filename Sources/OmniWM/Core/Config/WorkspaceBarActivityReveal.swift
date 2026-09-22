// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation

enum WorkspaceBarActivityReveal: String, CaseIterable, Codable, Identifiable {
    case off
    case workspace
    case workspaceAndColumn
    case focus

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .off: "Never"
        case .workspace: "Workspace Changes"
        case .workspaceAndColumn: "Workspace and Column Changes"
        case .focus: "Any Focused-Window Change"
        }
    }

    static func validatedDuration(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return 1 }
        return min(max(seconds, 0.1), 10)
    }
}
