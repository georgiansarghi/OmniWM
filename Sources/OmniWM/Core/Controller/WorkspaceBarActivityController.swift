// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation

@MainActor
final class WorkspaceBarActivityController {
    private weak var controller: WMController?
    private(set) var state = WorkspaceBarActivityState()
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private var expirationTask: Task<Void, Never>?
    private var scheduledDeadline: TimeInterval?

    init(controller: WMController) {
        self.controller = controller
    }

    func refresh() {
        guard let controller, controller.hasStartedServices else {
            stop()
            return
        }
        let previous = state.revealed
        state.update(targets: targets(controller: controller), now: now())
        scheduleExpiration()
        if state.revealed != previous {
            // Capture any hover/popup reason before an expiring activity reveal orders its panel out.
            controller.workspaceBarManager.refreshHover()
            controller.requestWorkspaceBarRefresh()
        }
    }

    func stop() {
        expirationTask?.cancel()
        expirationTask = nil
        scheduledDeadline = nil
        state.reset()
    }

    private func targets(controller: WMController) -> [WorkspaceBarActivityTarget] {
        let manager = controller.workspaceManager
        return manager.monitors.map { monitor in
            let resolved = controller.settings.workspaceBar.resolved(for: monitor)
            let workspaceId = manager.activeWorkspaceOrFirst(on: monitor.id)?.id
            let selected = manager.selectedManagedToken
            let focusedToken = selected.flatMap { token in
                workspaceId != nil && manager.workspace(for: token) == workspaceId ? token : nil
            }
            var columnId: NodeId?
            if let workspaceId, manager.activeLayoutKind(for: workspaceId) == .niri,
               let engine = controller.niriEngine,
               let nodeId = manager.niriViewportState(for: workspaceId).selectedNodeId,
               let node = engine.findNode(by: nodeId, in: workspaceId)
            {
                columnId = engine.column(of: node)?.id
            }
            return WorkspaceBarActivityTarget(
                monitorId: monitor.id, workspaceId: workspaceId, columnId: columnId, focusedToken: focusedToken,
                allowed: controller.canAutoRevealWorkspaceBar(on: monitor, resolved: resolved),
                mode: resolved.activityReveal, duration: resolved.activityRevealSeconds
            )
        }
    }

    private func scheduleExpiration() {
        guard scheduledDeadline != state.nextDeadline else { return }
        expirationTask?.cancel()
        scheduledDeadline = state.nextDeadline
        guard let deadline = scheduledDeadline else {
            expirationTask = nil
            return
        }
        let delay = max(0, deadline - now())
        expirationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            scheduledDeadline = nil
            expirationTask = nil
            refresh()
        }
    }
}
