// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import CoreGraphics

struct WorkspaceBarHoverTarget {
    let id: Monitor.ID
    let activationRegions: [CGRect]
    let retentionRegions: [CGRect]
    let isVisible: Bool
    let isPinned: Bool

    init(
        monitor: Monitor, frames: [CGRect], position: WorkspaceBarPosition,
        isVisible: Bool, isPinned: Bool, associatedFrames: [CGRect] = [], revealOnHover: Bool = true
    ) {
        id = monitor.id
        self.isVisible = isVisible
        self.isPinned = isPinned
        activationRegions = revealOnHover ? frames.map { frame in
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
        } : []
        // Interaction retention is independent of edge activation. Without hover reveal,
        // only the displayed controls (not their hidden edge corridor) keep the bar open.
        retentionRegions = (frames + associatedFrames).map {
            (revealOnHover ? $0.insetBy(dx: -20, dy: -20) : $0).intersection(monitor.frame)
        } + activationRegions
    }
}

struct WorkspaceBarHoverState {
    private(set) var revealed: Set<Monitor.ID> = []

    mutating func update(targets: [WorkspaceBarHoverTarget], pointer: CGPoint) {
        revealed = Set(targets.filter { target in
            let insideActivation = target.activationRegions.contains { $0.contains(pointer) }
            let keepVisible = (revealed.contains(target.id) || target.isVisible)
                && (target.isPinned || target.retentionRegions.contains { $0.contains(pointer) })
            return insideActivation || keepVisible
        }.map(\.id))
    }

    mutating func reset() {
        revealed = []
    }
}
