// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation

/// Normalize the old coupled auto-hide/modifier policy before decoding or preserving unknown TOML keys.
/// New visibility and hover keys always win, and the retired alias must not be restored as an unknown key.
enum WorkspaceBarVisibilityMigration {
    private struct LegacyPolicy {
        let autoHide: Bool?
        let hasModifier: Bool
        let hadVisibility: Bool
        let activity: TOMLNode

        var gatesActivity: Bool {
            !hadVisibility && autoHide != true && hasModifier
        }
    }

    static func normalize(_ raw: inout [String: TOMLNode]) throws {
        guard case var .table(bar) = raw["workspaceBar"] else { return }
        let policy = try LegacyPolicy(
            autoHide: legacyAutoHide(in: &bar, path: "workspaceBar"),
            hasModifier: bar["revealModifier"].map { $0 != .string("off") } ?? false,
            hadVisibility: bar["visibility"] != nil,
            activity: validatedActivity(in: bar, path: "workspaceBar") ?? .string("off")
        )
        if !policy.hadVisibility {
            bar["visibility"] = .string(policy.autoHide == true || policy.hasModifier ? "temporary" : "alwaysVisible")
            if bar["revealOnHover"] == nil {
                bar["revealOnHover"] = .boolean(policy.autoHide == true || !policy.hasModifier)
            }
        }
        // Previously activity required autoHide, so modifier-only scopes must not acquire a dormant trigger.
        if policy.gatesActivity { bar["activityReveal"] = .string("off") }
        raw["workspaceBar"] = .table(bar)
        guard case let .array(overrides) = raw["monitorBarOverrides"] else { return }
        raw["monitorBarOverrides"] = .array(try overrides.enumerated().map { index, node in
            try normalizeOverride(node, index: index, policy: policy)
        })
    }

    private static func normalizeOverride(_ node: TOMLNode, index: Int, policy: LegacyPolicy) throws -> TOMLNode {
        guard case var .table(override) = node else { return node }
        let hadOwnVisibility = override["visibility"] != nil
        let ownAutoHide = try legacyAutoHide(in: &override, path: "monitorBarOverrides[\(index)]")
        let ownActivity = try validatedActivity(in: override, path: "monitorBarOverrides[\(index)]")
        if let ownAutoHide {
            if !hadOwnVisibility {
                override["visibility"] = .string(ownAutoHide || policy.hasModifier ? "temporary" : "alwaysVisible")
            }
            if override["revealOnHover"] == nil {
                override["revealOnHover"] = .boolean(ownAutoHide)
            }
        }
        let legacyScope = !hadOwnVisibility && (ownAutoHide != nil || !policy.hadVisibility)
        if legacyScope && !(ownAutoHide ?? policy.autoHide ?? false) && policy.hasModifier {
            // Preserve inheritance when the normalized global trigger is already off.
            if ownActivity != nil || (!policy.gatesActivity && policy.activity != .string("off")) {
                override["activityReveal"] = .string("off")
            }
        } else if policy.gatesActivity && override["activityReveal"] == nil {
            // A legacy hover-enabled display (or explicit new mode) retains the original inherited activity preference.
            override["activityReveal"] = policy.activity
        }
        return .table(override)
    }

    private static func validatedActivity(in table: [String: TOMLNode], path: String) throws -> TOMLNode? {
        guard let value = table["activityReveal"] else { return nil }
        guard case let .string(mode) = value, WorkspaceBarActivityReveal(rawValue: mode) != nil else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [DynamicCodingKey(path), DynamicCodingKey("activityReveal")],
                debugDescription: "Invalid workspace bar activityReveal"
            ))
        }
        return value
    }

    private static func legacyAutoHide(in table: inout [String: TOMLNode], path: String) throws -> Bool? {
        guard let value = table.removeValue(forKey: "autoHide") else { return nil }
        guard case let .boolean(enabled) = value else {
            throw DecodingError.typeMismatch(Bool.self, .init(
                codingPath: [DynamicCodingKey(path), DynamicCodingKey("autoHide")],
                debugDescription: "Legacy workspace bar autoHide must be a boolean"
            ))
        }
        return enabled
    }
}
