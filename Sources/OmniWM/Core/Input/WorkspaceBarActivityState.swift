// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation

struct WorkspaceBarActivityTarget {
    let monitorId: Monitor.ID
    let workspaceId: WorkspaceDescriptor.ID?
    let columnId: NodeId?
    let focusedToken: WindowToken?
    let allowed: Bool
    let mode: WorkspaceBarActivityReveal
    let duration: TimeInterval
}

struct WorkspaceBarActivityState {
    private var previous: [Monitor.ID: WorkspaceBarActivityTarget] = [:]
    private(set) var deadlines: [Monitor.ID: TimeInterval] = [:]

    var nextDeadline: TimeInterval? {
        deadlines.values.min()
    }

    var revealed: Set<Monitor.ID> {
        Set(deadlines.keys)
    }

    mutating func update(targets: [WorkspaceBarActivityTarget], now: TimeInterval) {
        let ids = Set(targets.map(\.monitorId))
        previous = previous.filter { ids.contains($0.key) }
        deadlines = deadlines.filter { ids.contains($0.key) && $0.value > now }
        for target in targets {
            let old = previous.updateValue(target, forKey: target.monitorId)
            // First observation, configuration changes and suppression establish a new baseline, not activity.
            guard target.allowed, target.mode != .off,
                  let old, old.allowed, old.mode == target.mode, old.duration == target.duration
            else {
                deadlines.removeValue(forKey: target.monitorId)
                continue
            }
            let workspaceChanged = old.workspaceId != nil && target.workspaceId != nil
                && old.workspaceId != target.workspaceId
            let columnChanged = old.columnId != nil && target.columnId != nil && old.columnId != target.columnId
            let focusChanged = target.focusedToken != nil && old.focusedToken != target.focusedToken
            let changed = workspaceChanged
                || (target.mode == .workspaceAndColumn && columnChanged)
                || (target.mode == .focus && focusChanged)
            if changed {
                deadlines[target.monitorId] = now + WorkspaceBarActivityReveal.validatedDuration(target.duration)
            }
        }
    }

    mutating func reset() {
        previous = [:]
        deadlines = [:]
    }
}
