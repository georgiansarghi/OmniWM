// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
import SwiftUI

@MainActor
final class WorkspaceBarManager {
    var screenProvider: @MainActor (CGDirectDisplayID) -> NSScreen? = { displayId in
        NSScreen.screens.first(where: { $0.displayId == displayId })
    }

    var panelFactory: @MainActor @Sendable () -> WorkspaceBarPanel = {
        WorkspaceBarPanel.defaultPanel()
    }

    var frameApplier: @MainActor @Sendable (WorkspaceBarPanel, NSRect) -> Void = { panel, frame in
        panel.setFrame(frame, display: true)
    }

    private var barsByMonitor: [Monitor.ID: WorkspaceBarInstance] = [:]
    private var autoHideMonitorIds: Set<Monitor.ID> = []
    private lazy var hoverMonitor: WorkspaceBarHoverMonitor = {
        let monitor = WorkspaceBarHoverMonitor()
        monitor.targets = { [weak self] in self?.hoverTargets() ?? [] }
        monitor.pointer = { [weak self] in self?.controller?.currentMouseLocation() ?? NSEvent.mouseLocation }
        monitor.onRevealChanged = { [weak self] in self?.controller?.requestWorkspaceBarRefresh() }
        return monitor
    }()

    private weak var controller: WMController?
    private weak var settings: SettingsStore?
    private let motionPolicy: MotionPolicy
    private let surfaceCoordinator = SurfaceCoordinator.shared

    init(motionPolicy: MotionPolicy) {
        self.motionPolicy = motionPolicy
    }

    func setup(controller: WMController, settings: SettingsStore) {
        self.controller = controller
        self.settings = settings
        controller.systemStatsPopupController.onVisibilityChanged = { [weak self] in self?.refreshHover() }
        controller.hiddenBarController.onPanelVisibilityChanged = { [weak self] in self?.refreshHover() }
    }

    func apply(_ bars: [DesiredBarSurface]) {
        guard controller != nil, settings != nil else { return }

        autoHideMonitorIds = Set(bars.filter(\.retainWhileHidden).map { $0.monitor.id })
        var staleMonitorIds = Set(barsByMonitor.keys)
        for bar in bars where bar.visible || bar.retainWhileHidden {
            staleMonitorIds.remove(bar.monitor.id)
            if let existing = barsByMonitor[bar.monitor.id] {
                if !updateBarForMonitor(bar.monitor, snapshot: bar.snapshot, instance: existing) {
                    removeBarForMonitor(bar.monitor.id)
                    createBarForMonitor(bar.monitor, snapshot: bar.snapshot)
                }
            } else {
                createBarForMonitor(bar.monitor, snapshot: bar.snapshot)
            }
            applyVisibility(bar.visible, on: bar.monitor.id)
        }

        for monitorId in staleMonitorIds {
            removeBarForMonitor(monitorId)
        }
        if autoHideMonitorIds.isEmpty { hoverMonitor.stop() } else { hoverMonitor.start() }
    }

    func updateAppearance() {
        guard let settings else { return }

        for instance in barsByMonitor.values {
            instance.refreshAppearance(resolved: settings.workspaceBar.resolved(for: instance.monitor))
        }
    }

    private func createBarForMonitor(_ monitor: Monitor, snapshot: WorkspaceBarSnapshot) {
        guard let controller, let settings else { return }

        let resolved = settings.workspaceBar.resolved(for: monitor)
        let model = WorkspaceBarModel(snapshot: snapshot)
        let measurementView = NSHostingView(rootView: WorkspaceBarMeasurementView(snapshot: snapshot))
        let screen = screenProvider(monitor.displayId)
        let panel = panelFactory()
        panel.targetScreen = screen
        let primary = WorkspaceBarIslandPanel(
            panel: panel,
            rootView: makeBarView(
                model: model,
                slice: .all,
                showsSystemStatsButton: snapshot.showSystemStatsButton,
                monitorId: monitor.id,
                controller: controller
            ),
            resolved: resolved
        )

        let instance = WorkspaceBarInstance(
            monitor: monitor,
            primary: primary,
            measurementView: measurementView,
            model: model,
            screenDisplayId: screen?.displayId
        )
        let preparedSnapshot = instance.scratchpadCompactedSnapshot(
            snapshot,
            monitor: monitor,
            resolved: resolved
        )
        model.snapshot = preparedSnapshot
        barsByMonitor[monitor.id] = instance

        instance.applyCurrentAppearance()
        updateBarFrameAndPosition(
            for: monitor,
            resolved: resolved,
            snapshot: preparedSnapshot,
            instance: instance
        )
        surfaceCoordinator.register(
            window: primary.panel,
            id: instance.surfaceId(),
            policy: WorkspaceBarInstance.surfacePolicy
        )
    }

    private func updateBarForMonitor(
        _ monitor: Monitor,
        snapshot: WorkspaceBarSnapshot,
        instance: WorkspaceBarInstance
    ) -> Bool {
        guard let settings else { return false }

        let screen = screenProvider(monitor.displayId)
        guard instance.updateMonitor(monitor, screen: screen) else { return false }

        let resolved = settings.workspaceBar.resolved(for: monitor)
        let preparedSnapshot = instance.scratchpadCompactedSnapshot(
            snapshot,
            monitor: monitor,
            resolved: resolved
        )
        instance.updateSnapshot(preparedSnapshot)
        instance.applyCurrentAppearance()
        instance.applyPanelSettings(resolved: resolved)
        updateBarFrameAndPosition(
            for: monitor,
            resolved: resolved,
            snapshot: preparedSnapshot,
            instance: instance
        )
        return true
    }

    private func makeBarView(
        model: WorkspaceBarModel,
        slice: WorkspaceBarIslandSlice,
        showsSystemStatsButton: Bool,
        monitorId: Monitor.ID,
        controller: WMController
    ) -> WorkspaceBarView {
        WorkspaceBarView(
            model: model,
            slice: slice,
            showsSystemStatsButton: showsSystemStatsButton,
            motionPolicy: motionPolicy,
            onFocusWorkspace: { [weak controller] item in
                controller?.focusWorkspaceFromBar(id: item.id)
            },
            onFocusWindow: { [weak controller] handle in
                controller?.focusWindowFromBar(handle: handle)
            },
            onActivateScratchpad: { [weak controller] index in
                guard let index = ScratchpadIndex(index) else { return }
                controller?.activateScratchpadFromBar(index: index, on: monitorId)
            },
            onToggleSystemStats: { [weak controller] in
                controller?.toggleSystemStatsFromBar(on: monitorId)
            },
            onSystemStatsAnchorChange: { [weak self] anchor in
                self?.barsByMonitor[monitorId]?.statsAnchorView = anchor
            }
        )
    }

    private func removeBarForMonitor(_ monitorId: Monitor.ID) {
        if let instance = barsByMonitor[monitorId] {
            controller?.dismissSystemStatsPopup(anchoredTo: monitorId)
            removeSecondaryPanel(from: instance)
            surfaceCoordinator.unregister(id: instance.surfaceId())
            instance.primary.panel.orderOut(nil)
            instance.primary.panel.close()
            barsByMonitor.removeValue(forKey: monitorId)
        }
    }

    private func updateBarFrameAndPosition(
        for monitor: Monitor,
        resolved: ResolvedBarSettings,
        snapshot: WorkspaceBarSnapshot,
        instance: WorkspaceBarInstance
    ) {
        let geometry = WorkspaceBarGeometry.resolve(monitor: monitor, resolved: resolved, isVisible: true)
        if let split = instance.splitLayout(
            geometry: geometry,
            snapshot: snapshot,
            monitor: monitor,
            resolved: resolved
        ) {
            applySplitLayout(split, resolved: resolved, instance: instance)
        } else {
            updateIslandView(
                &instance.primary,
                model: instance.model,
                slice: .all,
                showsSystemStatsButton: snapshot.showSystemStatsButton,
                monitorId: instance.monitorId
            )
            removeSecondaryPanel(from: instance)
            let length = instance.measuredLength(
                for: snapshot,
                slice: .all,
                showsSystemStatsButton: snapshot.showSystemStatsButton
            )
            let frame = geometry.frame(fittingLength: length, monitor: monitor, resolved: resolved)
            instance.primary.applyFrame(frame, using: frameApplier)
        }
        if !snapshot.showSystemStatsButton {
            instance.statsAnchorView = nil
            controller?.dismissSystemStatsPopup(anchoredTo: instance.monitorId)
        }
    }

    private func updateIslandView(
        _ island: inout WorkspaceBarIslandPanel,
        model: WorkspaceBarModel,
        slice: WorkspaceBarIslandSlice,
        showsSystemStatsButton: Bool,
        monitorId: Monitor.ID
    ) {
        guard island.slice != slice || island.showsSystemStatsButton != showsSystemStatsButton,
              let controller
        else {
            return
        }
        island.slice = slice
        island.showsSystemStatsButton = showsSystemStatsButton
        island.hostingView.rootView = makeBarView(
            model: model,
            slice: slice,
            showsSystemStatsButton: showsSystemStatsButton,
            monitorId: monitorId,
            controller: controller
        )
    }

    private func makeSecondaryPanel(
        for instance: WorkspaceBarInstance,
        resolved: ResolvedBarSettings,
        showsSystemStatsButton: Bool
    ) -> WorkspaceBarIslandPanel? {
        guard let controller else { return nil }
        let screen = screenProvider(instance.monitor.displayId)
        let panel = panelFactory()
        panel.targetScreen = screen
        let island = WorkspaceBarIslandPanel(
            panel: panel,
            rootView: makeBarView(
                model: instance.model,
                slice: .secondary,
                showsSystemStatsButton: showsSystemStatsButton,
                monitorId: instance.monitorId,
                controller: controller
            ),
            resolved: resolved
        )
        surfaceCoordinator.register(
            window: island.panel,
            id: instance.secondarySurfaceId(),
            policy: WorkspaceBarInstance.surfacePolicy
        )
        return island
    }

    private func removeSecondaryPanel(from instance: WorkspaceBarInstance) {
        guard let secondary = instance.secondary else { return }
        surfaceCoordinator.unregister(id: instance.secondarySurfaceId())
        secondary.panel.orderOut(nil)
        secondary.panel.close()
        instance.secondary = nil
    }

    private func applySplitLayout(
        _ split: WorkspaceBarInstance.SplitLayoutResult,
        resolved: ResolvedBarSettings,
        instance: WorkspaceBarInstance
    ) {
        updateIslandView(
            &instance.primary,
            model: instance.model,
            slice: .active,
            showsSystemStatsButton: split.primaryShowsSystemStatsButton,
            monitorId: instance.monitorId
        )
        instance.primary.applyFrame(split.layout.activeFrame, using: frameApplier)
        if let secondaryFrame = split.layout.secondaryFrame,
           var secondary = instance.secondary ?? makeSecondaryPanel(
               for: instance,
               resolved: resolved,
               showsSystemStatsButton: split.secondaryShowsSystemStatsButton
           )
        {
            updateIslandView(
                &secondary,
                model: instance.model,
                slice: .secondary,
                showsSystemStatsButton: split.secondaryShowsSystemStatsButton,
                monitorId: instance.monitorId
            )
            secondary.applyFrame(secondaryFrame, using: frameApplier)
            instance.secondary = secondary
        } else {
            removeSecondaryPanel(from: instance)
        }
    }
}

extension WorkspaceBarManager {
    func cleanup() {
        autoHideMonitorIds = []
        hoverMonitor.stop()
        for monitorId in Array(barsByMonitor.keys) {
            removeBarForMonitor(monitorId)
        }
    }

    func isHoverRevealed(on monitorId: Monitor.ID) -> Bool {
        hoverMonitor.state.revealed.contains(monitorId)
    }

    func refreshHover() {
        hoverMonitor.refresh()
    }

    private func applyVisibility(_ visible: Bool, on monitorId: Monitor.ID) {
        guard let instance = barsByMonitor[monitorId] else { return }
        let panels = [instance.primary.panel, instance.secondary?.panel].compactMap { $0 }
        for panel in panels where panel.isVisible != visible {
            if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        }
        if !visible { controller?.dismissSystemStatsPopup(anchoredTo: monitorId) }
    }

    private func hoverTargets() -> [WorkspaceBarHoverTarget] {
        guard let controller, let settings else { return [] }
        return autoHideMonitorIds.compactMap { id in
            guard let instance = barsByMonitor[id] else { return nil }
            let resolved = settings.workspaceBar.resolved(for: instance.monitor)
            guard controller.canAutoRevealWorkspaceBar(on: instance.monitor, resolved: resolved) else { return nil }
            let panels = [instance.primary.panel, instance.secondary?.panel].compactMap { $0 }
            return WorkspaceBarHoverTarget(
                monitor: instance.monitor,
                frames: panels.map(\.frame),
                position: resolved.position,
                isVisible: instance.primary.panel.isVisible,
                isPinned: panels.contains { $0.attachedSheet != nil }
                    || controller.hasOpenWorkspaceBarPopup(on: instance.monitor),
                associatedFrames: [controller.hiddenBarController.statusItems.fallbackFrame(on: id)].compactMap { $0 }
            )
        }
    }

    func statsAnchor(on monitorId: Monitor.ID) -> CGPoint? {
        guard let view = barsByMonitor[monitorId]?.statsAnchorView,
              let window = view.window, window.isVisible else { return nil }
        let frame = window.convertToScreen(view.convert(view.bounds, to: nil))
        return WorkspaceBarGeometry.statsButtonAnchor(buttonFrame: frame)
    }

    func primaryDisplayedFrame(on monitorId: Monitor.ID) -> CGRect? {
        barsByMonitor[monitorId]?.primary.panel.frame
    }

    func popupAttachment(on monitorId: Monitor.ID, forStats: Bool = false) -> PopupAttachment? {
        guard let instance = barsByMonitor[monitorId], let settings else { return nil }
        let island = forStats && instance.secondary?.showsSystemStatsButton == true
            ? instance.secondary : instance.primary
        guard let island else { return nil }
        let edge = settings.workspaceBar.resolved(for: instance.monitor).position.popupEdge
        return PopupAttachment(
            sourceFrame: island.panel.frame, edge: edge,
            alignment: forStats ? statsAnchor(on: monitorId) : nil
        )
    }

    func isWorkspaceBarWindow(_ window: NSWindow) -> Bool {
        barsByMonitor.values.contains {
            $0.primary.panel === window || $0.secondary?.panel === window
        }
    }
}
