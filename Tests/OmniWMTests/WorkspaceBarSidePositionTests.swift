// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

@MainActor
final class WorkspaceBarSidePositionTests: XCTestCase {
    private let monitor = Monitor(
        id: .init(displayId: 7), displayId: 7,
        frame: CGRect(x: -1440, y: -900, width: 1440, height: 900),
        visibleFrame: CGRect(x: -1380, y: -900, width: 1320, height: 868),
        hasNotch: true, name: "Side Dock"
    )

    func testSidePositionsRoundTripGloballyAndPerMonitor() throws {
        for position in [WorkspaceBarPosition.left, .right] {
            var export = SettingsExport.defaults()
            export.workspaceBar.position = position
            export.monitorBarSettings = [MonitorBarSettings(monitorName: monitor.name, position: position)]
            let decoded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export))
            XCTAssertEqual(decoded.workspaceBar.position, position)
            XCTAssertEqual(decoded.monitorBarSettings[0].position, position)
        }
    }

    func testSidesUseVisibleEdgesOffsetsAndClampLength() {
        let settings = WorkspaceBarSettings()
        settings.height = 32
        settings.xOffset = 5
        settings.yOffset = -7
        settings.reserveLayoutSpace = true
        for position in [WorkspaceBarPosition.left, .right] {
            settings.position = position
            for mode in WorkspaceBarNotchMode.allCases {
                settings.notchMode = mode
                let resolved = settings.resolved(for: monitor)
                XCTAssertEqual(resolved.notchMode, .off)
                let geometry = WorkspaceBarGeometry.resolve(monitor: monitor, resolved: resolved, isVisible: true)
                let frame = geometry.frame(fittingLength: 200, monitor: monitor, resolved: resolved)
                XCTAssertEqual(frame.width, 32)
                XCTAssertEqual(frame.height, 200)
                XCTAssertEqual(frame.midY, monitor.visibleFrame.midY - 7)
                XCTAssertEqual(frame.minX, position == .left ? -1375 : -87)
                XCTAssertEqual(geometry.reservedInsets, position == .left ? Struts(left: 32) : Struts(right: 32))
                let full = geometry.frame(fittingLength: 5000, monitor: monitor, resolved: resolved)
                XCTAssertEqual(full.height, monitor.visibleFrame.height)
                let hidden = WorkspaceBarGeometry.resolve(monitor: monitor, resolved: resolved, isVisible: false)
                XCTAssertEqual(hidden.reservedInsets, .zero)
            }
        }
        settings.position = .overlappingMenuBar
        settings.update(MonitorBarSettings(monitorName: monitor.name, position: .right), for: monitor)
        XCTAssertEqual(settings.resolved(for: monitor).position, .right)
        XCTAssertEqual(settings.resolved(for: monitor).notchMode, .off)
        settings.remove(for: monitor)
        XCTAssertEqual(settings.resolved(for: monitor).notchMode, settings.notchMode)
    }

    func testFallbackIconDoesNotOverlapAFullHeightSideBar() {
        let settings = WorkspaceBarSettings()
        settings.height = 32
        for position in [WorkspaceBarPosition.left, .right] {
            settings.position = position
            let resolved = settings.resolved(for: monitor)
            let geometry = WorkspaceBarGeometry.resolve(monitor: monitor, resolved: resolved, isVisible: true)
            let bar = geometry.frame(fittingLength: 5000, monitor: monitor, resolved: resolved)
            let icon = HiddenBarFallbackIconController.iconFrame(
                monitor: monitor, barVisible: true, barFrame: bar, position: position
            )
            XCTAssertFalse(icon.intersects(bar))
            XCTAssertTrue(monitor.visibleFrame.contains(icon))
            let popup = PopupAttachment(sourceFrame: icon, edge: position.popupEdge)
                .frame(size: CGSize(width: 300, height: 400), visibleFrame: monitor.visibleFrame)
            XCTAssertFalse(popup.intersects(icon))
            XCTAssertFalse(popup.intersects(bar))
        }
    }

    func testSideReservationsReachTiledFullscreenAndBorderSafeFrames() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = SettingsStore(
            persistence: SettingsFilePersistence(directory: root, startWatching: false, deferSaves: false),
            runtimeState: RuntimeStateStore(directory: root.appendingPathComponent("state"), deferSaves: false),
            autosaveEnabled: false
        )
        settings.borders.enabled = false
        settings.gaps.outerGapLeft = 10
        settings.gaps.outerGapRight = 12
        settings.gaps.outerGapTop = 40
        settings.gaps.outerGapBottom = 14
        settings.workspaceBar.height = 32
        settings.workspaceBar.reserveLayoutSpace = true
        let controller = WMController(settings: settings)
        for position in [WorkspaceBarPosition.left, .right] {
            settings.workspaceBar.position = position
            let frames = controller.layoutFrames(for: monitor, scale: 1)
            XCTAssertEqual(frames.workingFrame.width, monitor.visibleFrame.width - 32 - 22)
            XCTAssertEqual(frames.workingFrame.minX, monitor.visibleFrame.minX + 10 + (position == .left ? 32 : 0))
            XCTAssertEqual(frames.fullscreenLayoutFrame.width, monitor.visibleFrame.width - 32)
            XCTAssertEqual(frames.fullscreenLayoutFrame.minX, monitor.visibleFrame.minX + (position == .left ? 32 : 0))
            XCTAssertEqual(frames.borderSafeFillFrame, frames.fullscreenLayoutFrame)
            settings.gaps.fullscreenUsesOuterGaps = true
            XCTAssertEqual(controller.layoutFrames(for: monitor, scale: 1).fullscreenLayoutFrame, frames.workingFrame)
            settings.gaps.fullscreenUsesOuterGaps = false
            settings.workspaceBar.visibility = .temporary
            settings.workspaceBar.revealModifier = .option
            XCTAssertEqual(controller.layoutFrames(for: monitor, scale: 1).fullscreenLayoutFrame, monitor.visibleFrame)
            settings.workspaceBar.visibility = .alwaysVisible
            settings.workspaceBar.revealModifier = .off
            settings.workspaceBar.reserveLayoutSpace = false
            XCTAssertEqual(controller.layoutFrames(for: monitor, scale: 1).fullscreenLayoutFrame, monitor.visibleFrame)
            settings.workspaceBar.reserveLayoutSpace = true
        }
    }
}
