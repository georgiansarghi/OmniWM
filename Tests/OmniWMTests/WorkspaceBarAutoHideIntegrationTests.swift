// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

@MainActor
final class WorkspaceBarAutoHideIntegrationTests: XCTestCase {
    func testHiddenPanelIsReusedAndHoverDoesNotChangeWindowLayout() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let before = fixture.controller.layoutFrames(for: fixture.monitor, scale: 1)
        fixture.apply()
        XCTAssertEqual(fixture.panelCount, 1)
        XCTAssertFalse(fixture.panel.isVisible)
        XCTAssertNotNil(fixture.manager.primaryDisplayedFrame(on: fixture.monitor.id))
        fixture.pointer = fixture.panel.frame.center
        fixture.manager.refreshHover()
        XCTAssertTrue(fixture.manager.isHoverRevealed(on: fixture.monitor.id))
        fixture.apply()
        XCTAssertTrue(fixture.panel.isVisible)
        XCTAssertEqual(fixture.panelCount, 1)
        XCTAssertEqual(
            fixture.controller.layoutFrames(for: fixture.monitor, scale: 1).workingFrame,
            before.workingFrame
        )
        XCTAssertEqual(fixture.controller.fullscreenLayoutFrame(for: fixture.monitor), fixture.monitor.visibleFrame)
        fixture.pointer = fixture.monitor.frame.center
        fixture.manager.refreshHover()
        XCTAssertFalse(fixture.manager.isHoverRevealed(on: fixture.monitor.id))
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
        XCTAssertNil(fixture.manager.statsAnchor(on: fixture.monitor.id))
        XCTAssertEqual(fixture.panelCount, 1)
        XCTAssertFalse(SurfaceCoordinator.shared.containsInteractive(point: fixture.panel.frame.center))
        XCTAssertEqual(
            fixture.controller.layoutFrames(for: fixture.monitor, scale: 1).workingFrame,
            before.workingFrame
        )
    }

    func testPopupKeepsBarOpenUntilDismissedEvenWithPointerAway() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.apply()
        fixture.pointer = fixture.panel.frame.center
        fixture.manager.refreshHover()
        try await fixture.waitForReveal(true)
        fixture.apply()
        fixture.controller.systemStatsPopupController.toggle(
            attachment: PopupAttachment(sourceFrame: fixture.panel.frame, edge: .above),
            monitorId: fixture.monitor.id, screenVisibleFrame: fixture.monitor.visibleFrame
        )
        fixture.pointer = fixture.monitor.frame.center
        fixture.manager.refreshHover()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(fixture.manager.isHoverRevealed(on: fixture.monitor.id))
        fixture.controller.systemStatsPopupController.dismiss()
        try await fixture.waitForReveal(false)
        fixture.apply()
        XCTAssertFalse(fixture.panel.isVisible)
    }

    func testWindowListSheetPinsBarUntilSheetEnds() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.apply()
        fixture.pointer = fixture.panel.frame.center
        fixture.manager.refreshHover()
        try await fixture.waitForReveal(true)
        fixture.apply()
        let sheet = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        defer {
            if fixture.panel.attachedSheet === sheet { fixture.panel.endSheet(sheet) }
            sheet.orderOut(nil)
        }
        fixture.panel.beginSheet(sheet, completionHandler: nil)
        fixture.pointer = fixture.monitor.frame.center
        fixture.manager.refreshHover()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(fixture.manager.isHoverRevealed(on: fixture.monitor.id))
        fixture.panel.endSheet(sheet)
        sheet.orderOut(nil)
        try await fixture.waitForReveal(false)
    }

    func testModifierIsAlternativeButManualHideDisableAndFullscreenTakePrecedence() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let controller = fixture.controller
        let bar = fixture.settings.workspaceBar
        bar.revealModifier = .option
        XCTAssertFalse(controller.isWorkspaceBarVisible(on: fixture.monitor))
        controller.setWorkspaceBarRevealHeld(true)
        XCTAssertTrue(controller.isWorkspaceBarVisible(on: fixture.monitor))
        XCTAssertTrue(controller.toggleWorkspaceBarVisibility())
        XCTAssertFalse(controller.isWorkspaceBarVisible(on: fixture.monitor))
        XCTAssertFalse(controller.canTemporarilyRevealWorkspaceBar(
            on: fixture.monitor,
            resolved: bar.resolved(for: fixture.monitor)
        ))
        XCTAssertTrue(controller.toggleWorkspaceBarVisibility())
        bar.enabled = false
        XCTAssertFalse(controller.isWorkspaceBarVisible(on: fixture.monitor))
        XCTAssertFalse(controller.canTemporarilyRevealWorkspaceBar(
            on: fixture.monitor,
            resolved: bar.resolved(for: fixture.monitor)
        ))
        bar.enabled = true
        controller.workspaceManager.commitSpaceTopology(SpaceTopology(
            displays: [.init(displayIdentifier: String(fixture.monitor.displayId), spaceIds: [1], currentSpaceId: 1)],
            activeSpaceId: 1, fullscreenSpaceIds: [1], windowSpace: [:]
        ))
        bar.hideInNativeFullscreen = true
        XCTAssertFalse(controller.isWorkspaceBarVisible(on: fixture.monitor))
        XCTAssertFalse(controller.canTemporarilyRevealWorkspaceBar(
            on: fixture.monitor,
            resolved: bar.resolved(for: fixture.monitor)
        ))
        bar.hideInNativeFullscreen = false
        XCTAssertTrue(controller.canTemporarilyRevealWorkspaceBar(
            on: fixture.monitor,
            resolved: bar.resolved(for: fixture.monitor)
        ))
        bar.position = .overlappingMenuBar
        bar.notchMode = .fillLeftOfNotch
        XCTAssertFalse(controller.canTemporarilyRevealWorkspaceBar(
            on: fixture.monitor,
            resolved: bar.resolved(for: fixture.monitor)
        ))
    }

    func testCleanupRemovesRetainedPanelAndPreventsLateReveal() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.apply()
        fixture.pointer = fixture.panel.frame.center
        fixture.manager.refreshHover()
        fixture.controller.hasStartedServices = false
        fixture.controller.surfaceReconciler.cleanup()
        fixture.manager.cleanup()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(fixture.manager.isHoverRevealed(on: fixture.monitor.id))
        XCTAssertNil(fixture.manager.primaryDisplayedFrame(on: fixture.monitor.id))
        XCTAssertFalse(fixture.panel.isVisible)
    }

    @MainActor
    private final class Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let settings: SettingsStore
        let controller: WMController
        let monitor: Monitor
        let panel = WorkspaceBarPanel.defaultPanel()
        var panelCount = 0
        var pointer = CGPoint(x: -100000, y: -100000)
        var manager: WorkspaceBarManager {
            controller.workspaceBarManager
        }

        init() throws {
            let screen = try XCTUnwrap(NSScreen.main)
            let displayId = try XCTUnwrap(screen.displayId)
            monitor = Monitor(
                id: .init(displayId: displayId), displayId: displayId, frame: screen.frame,
                visibleFrame: screen.visibleFrame, hasNotch: false, name: "Hover Test"
            )
            settings = SettingsStore(
                persistence: SettingsFilePersistence(directory: root, startWatching: false, deferSaves: false),
                runtimeState: RuntimeStateStore(directory: root.appendingPathComponent("state"), deferSaves: false),
                autosaveEnabled: false
            )
            settings.workspaceBar.visibility = .temporary
            settings.workspaceBar.position = .bottom
            settings.workspaceBar.reserveLayoutSpace = true
            settings.workspaceBar.height = 32
            controller = WMController(settings: settings)
            controller.hasStartedServices = true
            controller.workspaceManager.replaceMonitorsForTopologyTransition(with: [monitor])
            _ = controller.workspaceManager.setInteractionMonitor(monitor.id)
            controller.currentMouseLocation = { [weak self] in self?.pointer ?? .zero }
            manager.setup(controller: controller, settings: settings)
            manager.panelFactory = { [unowned self] in
                panelCount += 1
                return panel
            }
        }

        func apply() {
            controller.surfaceReconciler.reconcileNow()
        }

        func waitForReveal(_ revealed: Bool) async throws {
            for _ in 0 ..< 100 where manager.isHoverRevealed(on: monitor.id) != revealed {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertEqual(manager.isHoverRevealed(on: monitor.id), revealed)
        }

        func cleanup() {
            controller.hasStartedServices = false
            controller.systemStatsPopupController.dismiss()
            manager.cleanup()
            controller.surfaceReconciler.cleanup()
            try? FileManager.default.removeItem(at: root)
        }
    }
}
