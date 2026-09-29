// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

@MainActor
final class WorkspaceBarVisibilityTopologyTests: XCTestCase {
    func testHotPlugStartsModifierMonitoringOnlyForTemporaryDisplaysAndDisconnectStopsIt() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let settings = SettingsStore(
            persistence: SettingsFilePersistence(directory: root, startWatching: false, deferSaves: false),
            runtimeState: RuntimeStateStore(directory: root.appendingPathComponent("state"), deferSaves: false),
            autosaveEnabled: false
        )
        settings.pointer.enabled = false
        settings.workspaceBar.visibility = .alwaysVisible
        settings.workspaceBar.revealModifier = .option
        settings.workspaceBar.revealHoldMilliseconds = 0
        settings.workspaceBar.reserveLayoutSpace = true
        settings.workspaceBar.position = .bottom
        let internalDisplay = monitor(id: 601, name: "Internal", x: 0)
        let externalDisplay = monitor(id: 602, name: "External", x: 1440)
        settings.workspaceBar.update(MonitorBarSettings(
            monitorName: externalDisplay.name, visibility: .temporary, revealOnHover: false, activityReveal: .off
        ), for: externalDisplay)
        let controller = WMController(settings: settings)
        controller.hasStartedServices = true
        defer {
            controller.hasStartedServices = false
            controller.workspaceBarRevealMonitor.stop()
            controller.workspaceBarManager.cleanup()
            controller.surfaceReconciler.cleanup()
            try? FileManager.default.removeItem(at: root)
        }
        let handler = controller.serviceLifecycleManager.monitorConfiguration
        let reveal = controller.workspaceBarRevealMonitor
        handler.applyMonitorConfigurationChanged(currentMonitors: [internalDisplay], performPostUpdateActions: false)
        XCTAssertFalse(reveal.isMonitoring)
        XCTAssertTrue(controller.isWorkspaceBarVisible(on: internalDisplay))
        let reserved = controller.insetWorkingFrame(for: internalDisplay)
        for _ in 0 ..< 2 {
            handler.applyMonitorConfigurationChanged(
                currentMonitors: [internalDisplay, externalDisplay], performPostUpdateActions: false
            )
            XCTAssertTrue(reveal.isMonitoring)
            reveal.handleFlagsChanged(rawFlags: 0)
            XCTAssertFalse(controller.isWorkspaceBarVisible(on: externalDisplay))
            reveal.handleFlagsChanged(rawFlags: UInt64(NSEvent.ModifierFlags.option.rawValue))
            XCTAssertTrue(controller.isWorkspaceBarVisible(on: externalDisplay))
            XCTAssertTrue(controller.isWorkspaceBarVisible(on: internalDisplay))
            XCTAssertEqual(controller.insetWorkingFrame(for: internalDisplay), reserved)
            XCTAssertEqual(controller.fullscreenLayoutFrame(for: externalDisplay), externalDisplay.visibleFrame)
            reveal.handleFlagsChanged(rawFlags: 0)
            XCTAssertFalse(controller.isWorkspaceBarVisible(on: externalDisplay))
            handler.applyMonitorConfigurationChanged(
                currentMonitors: [internalDisplay],
                performPostUpdateActions: false
            )
            XCTAssertFalse(reveal.isMonitoring)
            XCTAssertFalse(controller.isWorkspaceBarRevealHeld)
        }
    }

    private func monitor(id: CGDirectDisplayID, name: String, x: CGFloat) -> Monitor {
        Monitor(
            id: .init(displayId: id), displayId: id,
            frame: CGRect(x: x, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: x, y: 0, width: 1440, height: 870), hasNotch: false, name: name
        )
    }
}
