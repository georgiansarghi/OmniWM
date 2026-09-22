// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

@MainActor
final class WorkspaceBarActivityIntegrationTests: XCTestCase {
    func testWorkspaceChangeShowsReusedPanelWithoutChangingLayoutAndExpires() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let before = fixture.controller.layoutFrames(for: fixture.monitor, scale: 1).workingFrame
        XCTAssertFalse(fixture.panel.isVisible)
        fixture.switchWorkspace(fixture.second)
        XCTAssertTrue(fixture.activity.state.revealed.contains(fixture.monitor.id))
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        XCTAssertEqual(fixture.panelCount, 1)
        XCTAssertEqual(fixture.controller.layoutFrames(for: fixture.monitor, scale: 1).workingFrame, before)
        fixture.time = 0.8
        fixture.switchWorkspace(fixture.first)
        XCTAssertEqual(fixture.activity.state.nextDeadline, 1.8)
        fixture.time = 1.1
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.time = 1.8
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
        XCTAssertEqual(fixture.panelCount, 1)
        XCTAssertEqual(fixture.controller.layoutFrames(for: fixture.monitor, scale: 1).workingFrame, before)
    }

    func testActivityOnlyIgnoresPointerBeforeRevealAndAfterExpiration() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        XCTAssertFalse(fixture.settings.workspaceBar.revealOnHover)
        fixture.pointer = fixture.panel.frame.center
        fixture.controller.workspaceBarManager.refreshHover()
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
        fixture.switchWorkspace(fixture.second)
        fixture.pointer = fixture.monitor.frame.center
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.time = 1
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
        fixture.pointer = fixture.panel.frame.center
        fixture.controller.workspaceBarManager.refreshHover()
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
    }

    func testAlwaysVisibleIgnoresStoredTriggersAndReturningToTemporaryPreservesThem() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.settings.workspaceBar.revealModifier = .option
        fixture.settings.workspaceBar.visibility = .alwaysVisible
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.switchWorkspace(fixture.second)
        XCTAssertNil(fixture.activity.state.nextDeadline)
        fixture.controller.setWorkspaceBarRevealHeld(true)
        fixture.controller.setWorkspaceBarRevealHeld(false)
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.settings.workspaceBar.visibility = .temporary
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
        XCTAssertEqual(fixture.settings.workspaceBar.activityReveal, .workspaceAndColumn)
        XCTAssertEqual(fixture.settings.workspaceBar.revealModifier, .option)
        XCTAssertFalse(fixture.settings.workspaceBar.revealOnHover)
        fixture.controller.setWorkspaceBarRevealHeld(true)
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.controller.setWorkspaceBarRevealHeld(false)
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
    }

    func testColumnSelectionChangesRevealButSameColumnAndViewportAnimationDoNot() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.settings.workspaceBar.activityReveal = .off
        let first = fixture.addWindow(id: 1)
        let second = fixture.addWindow(id: 2)
        fixture.select(first)
        fixture.settings.workspaceBar.activityReveal = .workspaceAndColumn
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        fixture.select(second)
        XCTAssertEqual(fixture.activity.state.nextDeadline, 1)
        fixture.time = 0.5
        fixture.select(second)
        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.first) { $0.viewOffset = 30 }
        XCTAssertEqual(fixture.activity.state.nextDeadline, 1)
        fixture.time = 1
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
        fixture.settings.workspaceBar.activityReveal = .workspace
        fixture.apply()
        fixture.select(first)
        XCTAssertNil(fixture.activity.state.nextDeadline)
    }

    func testAnyFocusModeObservesManagedFocusWithoutAColumnChange() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.settings.workspaceBar.activityReveal = .off
        let first = fixture.addWindow(id: 1)
        let second = fixture.addWindow(id: 2)
        let manager = fixture.controller.workspaceManager
        XCTAssertTrue(manager.setManagedFocus(first.token, in: fixture.first))
        fixture.settings.workspaceBar.activityReveal = .focus
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertTrue(manager.setManagedFocus(second.token, in: fixture.first))
        XCTAssertEqual(fixture.activity.state.nextDeadline, 1)
    }

    func testHoverAndPopupKeepBarOpenAfterActivityExpires() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.switchWorkspace(fixture.second)
        fixture.apply()
        fixture.pointer = fixture.panel.frame.center
        // No mouse event is needed for the handoff at expiration.
        fixture.time = 1
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.controller.systemStatsPopupController.toggle(
            attachment: PopupAttachment(sourceFrame: fixture.panel.frame, edge: .above),
            monitorId: fixture.monitor.id, screenVisibleFrame: fixture.monitor.visibleFrame
        )
        fixture.pointer = fixture.monitor.frame.center
        fixture.controller.workspaceBarManager.refreshHover()
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.controller.systemStatsPopupController.dismiss()
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
    }

    func testPopupOpenedDuringActivityRemainsOpenAfterExpiration() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.switchWorkspace(fixture.second)
        fixture.apply()
        fixture.controller.systemStatsPopupController.toggle(
            attachment: PopupAttachment(sourceFrame: fixture.panel.frame, edge: .above),
            monitorId: fixture.monitor.id, screenVisibleFrame: fixture.monitor.visibleFrame
        )
        fixture.time = 1
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertTrue(fixture.panel.isVisible)
        fixture.controller.systemStatsPopupController.dismiss()
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
    }

    func testManualHideAutoHideOffFullscreenAndCleanupCancelActivity() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.switchWorkspace(fixture.second)
        XCTAssertTrue(fixture.controller.toggleWorkspaceBarVisibility())
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertFalse(fixture.panel.isVisible)
        XCTAssertTrue(fixture.controller.toggleWorkspaceBarVisibility())
        fixture.apply()
        fixture.switchWorkspace(fixture.first)
        XCTAssertNotNil(fixture.activity.state.nextDeadline)
        fixture.settings.workspaceBar.visibility = .alwaysVisible
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        fixture.settings.workspaceBar.visibility = .temporary
        fixture.apply()
        fixture.switchWorkspace(fixture.second)
        fixture.settings.workspaceBar.hideInNativeFullscreen = true
        fixture.controller.workspaceManager.commitSpaceTopology(SpaceTopology(
            displays: [.init(displayIdentifier: String(fixture.monitor.displayId), spaceIds: [1], currentSpaceId: 1)],
            activeSpaceId: 1, fullscreenSpaceIds: [1], windowSpace: [:]
        ))
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertFalse(fixture.panel.isVisible)
        fixture.settings.workspaceBar.hideInNativeFullscreen = false
        fixture.apply()
        XCTAssertNil(fixture.activity.state.nextDeadline)
        fixture.switchWorkspace(fixture.first)
        XCTAssertNotNil(fixture.activity.state.nextDeadline)
        fixture.controller.workspaceBarManager.cleanup()
        XCTAssertNil(fixture.activity.state.nextDeadline)
    }

    func testDeadlineExpiresWithoutAnotherInputEvent() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.activity.now = { ProcessInfo.processInfo.systemUptime }
        fixture.settings.workspaceBar.activityRevealSeconds = 0.1
        fixture.apply()
        fixture.switchWorkspace(fixture.second)
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        for _ in 0 ..< 100 where fixture.panel.isVisible {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertFalse(fixture.panel.isVisible)
    }

    func testExtendingDeadlineCancelsOldTimerAndStoppingClearsTheNewOne() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.activity.now = { ProcessInfo.processInfo.systemUptime }
        fixture.settings.workspaceBar.activityRevealSeconds = 0.3
        fixture.apply()
        fixture.switchWorkspace(fixture.second)
        let originalDeadline = try XCTUnwrap(fixture.activity.state.nextDeadline)
        try await Task.sleep(for: .milliseconds(150))
        fixture.switchWorkspace(fixture.first)
        let extendedDeadline = try XCTUnwrap(fixture.activity.state.nextDeadline)
        XCTAssertGreaterThan(extendedDeadline, originalDeadline)
        // Cross the old deadline while remaining before the replacement deadline.
        try await Task.sleep(for: .seconds(max(0, originalDeadline - fixture.activity.now()) + 0.02))
        XCTAssertEqual(fixture.activity.state.nextDeadline, extendedDeadline)
        fixture.controller.hasStartedServices = false
        fixture.controller.workspaceBarManager.cleanup()
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertNil(fixture.activity.state.nextDeadline)
        XCTAssertFalse(fixture.panel.isVisible)
    }

    @MainActor
    private final class Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let settings: SettingsStore
        let controller: WMController
        let monitor: Monitor
        let first: WorkspaceDescriptor.ID
        let second: WorkspaceDescriptor.ID
        let panel = WorkspaceBarPanel.defaultPanel()
        var panelCount = 0
        var pointer = CGPoint(x: -100000, y: -100000)
        var time: TimeInterval = 0
        var activity: WorkspaceBarActivityController {
            controller.workspaceBarActivityController
        }

        init() throws {
            let screen = try XCTUnwrap(NSScreen.main)
            let displayId = try XCTUnwrap(screen.displayId)
            monitor = Monitor(
                id: .init(displayId: displayId), displayId: displayId, frame: screen.frame,
                visibleFrame: screen.visibleFrame, hasNotch: false, name: "Activity Test"
            )
            settings = SettingsStore(
                persistence: SettingsFilePersistence(directory: root, startWatching: false, deferSaves: false),
                runtimeState: RuntimeStateStore(directory: root.appendingPathComponent("state"), deferSaves: false),
                autosaveEnabled: false
            )
            settings.workspaces.configurations = [
                WorkspaceConfiguration(name: "1", layoutType: .niri),
                WorkspaceConfiguration(name: "2", layoutType: .niri)
            ]
            settings.workspaceBar.visibility = .temporary
            settings.workspaceBar.revealOnHover = false
            settings.workspaceBar.activityReveal = .workspaceAndColumn
            settings.workspaceBar.position = .bottom
            settings.workspaceBar.reserveLayoutSpace = true
            controller = WMController(settings: settings)
            controller.niriEngine = NiriLayoutEngine()
            controller.workspaceManager.applyMonitorConfigurationChange([monitor])
            controller.workspaceManager.applySettings()
            first = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "1"))
            second = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "2"))
            _ = controller.workspaceManager.setActiveWorkspace(first, on: monitor.id)
            controller.currentMouseLocation = { [weak self] in self?.pointer ?? .zero }
            activity.now = { [weak self] in self?.time ?? 0 }
            controller.workspaceBarManager.setup(controller: controller, settings: settings)
            controller.workspaceBarManager.panelFactory = { [unowned self] in
                panelCount += 1
                return panel
            }
            controller.hasStartedServices = true
            apply()
        }

        func switchWorkspace(_ id: WorkspaceDescriptor.ID) {
            XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(id, on: monitor.id))
        }

        func addWindow(id: Int) -> NiriWindow {
            let pid: pid_t = 493001
            let token = controller.workspaceManager.addWindow(
                AXWindowRef(element: AXUIElementCreateApplication(pid), windowId: id),
                pid: pid, windowId: id, to: first
            )
            return controller.workspaceManager.withEngineMutationScope(in: first) {
                controller.niriEngine!.addWindow(token: token, to: first, afterSelection: nil)
            }
        }

        func select(_ node: NiriWindow) {
            controller.workspaceManager.commitWorkspaceSelection(
                nodeId: node.id, focusedToken: node.token, in: first, onMonitor: monitor.id
            )
        }

        func apply() {
            controller.surfaceReconciler.reconcileNow()
        }

        func cleanup() {
            controller.hasStartedServices = false
            controller.systemStatsPopupController.dismiss()
            controller.workspaceBarManager.cleanup()
            controller.surfaceReconciler.cleanup()
            try? FileManager.default.removeItem(at: root)
        }
    }
}
