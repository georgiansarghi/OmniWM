// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import CoreGraphics
import Foundation

struct WorkspaceBarHoverTarget {
    let id: Monitor.ID
    let activationRegions: [CGRect]
    let retentionRegions: [CGRect]
    let isVisible: Bool
    let isPinned: Bool

    init(
        monitor: Monitor, frames: [CGRect], position: WorkspaceBarPosition,
        isVisible: Bool, isPinned: Bool, associatedFrames: [CGRect] = []
    ) {
        id = monitor.id
        self.isVisible = isVisible
        self.isPinned = isPinned
        activationRegions = frames.map { frame in
            let edge: CGRect = switch position {
            case .overlappingMenuBar,
                 .belowMenuBar:
                CGRect(x: frame.minX, y: monitor.frame.maxY - 1, width: frame.width, height: 1)
            case .bottom:
                CGRect(x: frame.minX, y: monitor.visibleFrame.minY, width: frame.width, height: 1)
            case .left:
                CGRect(x: monitor.visibleFrame.minX, y: frame.minY, width: 1, height: frame.height)
            case .right:
                CGRect(x: monitor.visibleFrame.maxX - 1, y: frame.minY, width: 1, height: frame.height)
            }
            return frame.union(edge).insetBy(dx: -8, dy: -8).intersection(monitor.frame)
        }
        retentionRegions = (frames + associatedFrames).map { $0.insetBy(dx: -20, dy: -20).intersection(monitor.frame) }
            + activationRegions
    }
}

struct WorkspaceBarHoverState {
    static let revealDelay: TimeInterval = 0.15
    static let hideDelay: TimeInterval = 0.4

    private struct Pending {
        let reveal: Bool
        let deadline: TimeInterval
    }

    private(set) var revealed: Set<Monitor.ID> = []
    private var pending: [Monitor.ID: Pending] = [:]

    var nextDeadline: TimeInterval? {
        pending.values.map(\.deadline).min()
    }

    mutating func update(targets: [WorkspaceBarHoverTarget], pointer: CGPoint, now: TimeInterval) {
        let ids = Set(targets.map(\.id))
        revealed.formIntersection(ids)
        pending = pending.filter { ids.contains($0.key) }
        for target in targets {
            let wasRevealed = revealed.contains(target.id)
            let insideActivation = target.activationRegions.contains { $0.contains(pointer) }
            let keepVisible = (wasRevealed || target.isVisible)
                && (target.isPinned || target.retentionRegions.contains { $0.contains(pointer) })
            let desired = insideActivation || keepVisible
            if desired == wasRevealed {
                pending.removeValue(forKey: target.id)
                continue
            }
            let delay = desired ? (target.isVisible ? 0 : Self.revealDelay) : Self.hideDelay
            if pending[target.id]?.reveal != desired || (desired && target.isVisible) {
                pending[target.id] = Pending(reveal: desired, deadline: now + delay)
            }
            if let transition = pending[target.id], now >= transition.deadline {
                if desired { revealed.insert(target.id) } else { revealed.remove(target.id) }
                pending.removeValue(forKey: target.id)
            }
        }
    }

    mutating func reset() {
        revealed = []
        pending = [:]
    }
}
