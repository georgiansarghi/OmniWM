// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit

@MainActor
final class WorkspaceBarHoverMonitor {
    var targets: () -> [WorkspaceBarHoverTarget] = { [] }
    var pointer: () -> CGPoint = { NSEvent.mouseLocation }
    var onRevealChanged: () -> Void = {}
    private(set) var state = WorkspaceBarHoverState()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var transitionTask: Task<Void, Never>?
    private var scheduledDeadline: TimeInterval?
    private(set) var isRunning = false

    func start() {
        if !isRunning {
            isRunning = true
            let mask: NSEvent.EventTypeMask = [
                .mouseMoved,
                .leftMouseDragged,
                .rightMouseDragged,
                .otherMouseDragged,
                .leftMouseDown,
                .rightMouseDown,
                .leftMouseUp,
                .rightMouseUp
            ]
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                self?.refresh()
                return event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            for name in [
                NSWindow.willBeginSheetNotification,
                NSWindow.didEndSheetNotification,
                NSWindow.didMoveNotification,
                NSWindow.didResizeNotification,
                NSWindow.didChangeOcclusionStateNotification
            ] {
                observers.append(NotificationCenter.default.addObserver(
                    forName: name, object: nil, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in self?.refresh() }
                })
            }
        }
        refresh()
    }

    func refresh() {
        guard isRunning else { return }
        let previous = state.revealed
        state.update(targets: targets(), pointer: pointer(), now: ProcessInfo.processInfo.systemUptime)
        scheduleTransition()
        if previous != state.revealed { onRevealChanged() }
    }

    func stop() {
        isRunning = false
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        transitionTask?.cancel()
        transitionTask = nil
        scheduledDeadline = nil
        let hadReveal = !state.revealed.isEmpty
        state.reset()
        if hadReveal { onRevealChanged() }
    }

    private func scheduleTransition() {
        guard scheduledDeadline != state.nextDeadline else { return }
        transitionTask?.cancel()
        scheduledDeadline = state.nextDeadline
        guard let deadline = scheduledDeadline else {
            transitionTask = nil
            return
        }
        let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        transitionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            scheduledDeadline = nil
            transitionTask = nil
            refresh()
        }
    }
}
