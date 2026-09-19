// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import CoreGraphics
import Foundation
@testable import OmniWM
import XCTest

final class WorkspaceBarBottomPositionTests: XCTestCase {
    private func monitor(bottom: CGFloat = -840) -> Monitor {
        Monitor(
            id: .init(displayId: 7),
            displayId: 7,
            frame: CGRect(x: -1440, y: -900, width: 1440, height: 900),
            visibleFrame: CGRect(x: -1440, y: bottom, width: 1440, height: -32 - bottom),
            hasNotch: true,
            name: "External"
        )
    }

    func testPositionRoundTripsGloballyAndPerDisplay() throws {
        var export = SettingsExport.defaults()
        export.workspaceBar.position = .bottom
        export.monitorBarSettings = [
            MonitorBarSettings(monitorName: "External", position: .bottom),
            MonitorBarSettings(monitorName: "Inherited")
        ]
        let data = try SettingsTOMLCodec.encode(export)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("position = \"bottom\""))
        let decoded = try SettingsTOMLCodec.decode(data)
        XCTAssertEqual(decoded.workspaceBar.position, .bottom)
        XCTAssertEqual(decoded.monitorBarSettings[0].position, .bottom)
        XCTAssertNil(decoded.monitorBarSettings[1].position)
    }

    @MainActor
    func testBottomUsesVisibleLowerEdgeAndPreservesOffsets() {
        let settings = WorkspaceBarSettings()
        settings.position = .bottom
        settings.height = 30
        settings.xOffset = 12
        settings.yOffset = 6
        for bottom in [CGFloat(-900), CGFloat(-840)] {
            let monitor = monitor(bottom: bottom)
            let resolved = settings.resolved(for: monitor)
            let geometry = WorkspaceBarGeometry.resolve(monitor: monitor, resolved: resolved, isVisible: true)
            XCTAssertEqual(geometry.effectivePosition, .bottom)
            XCTAssertEqual(
                geometry.frame(fittingWidth: 200, monitor: monitor, resolved: resolved),
                CGRect(x: -808, y: bottom + 6, width: 200, height: 30)
            )
        }
    }

    @MainActor
    func testReservationMovesToBottomAndDisappearsWhenHiddenOrDisabled() {
        let settings = WorkspaceBarSettings()
        settings.position = .bottom
        settings.height = 30
        let monitor = monitor()
        for reserve in [true, false] {
            settings.reserveLayoutSpace = reserve
            for visible in [true, false] {
                let geometry = WorkspaceBarGeometry.resolve(
                    monitor: monitor, resolved: settings.resolved(for: monitor), isVisible: visible
                )
                XCTAssertEqual(geometry.reservedTopInset, 0)
                XCTAssertEqual(geometry.reservedBottomInset, reserve && visible ? 30 : 0)
            }
        }
        settings.position = .belowMenuBar
        settings.reserveLayoutSpace = true
        let geometry = WorkspaceBarGeometry.resolve(
            monitor: monitor, resolved: settings.resolved(for: monitor), isVisible: true
        )
        XCTAssertEqual(geometry.reservedTopInset, 30)
        XCTAssertEqual(geometry.reservedBottomInset, 0)
    }

    @MainActor
    func testBottomIgnoresNotchModesWithoutChangingStoredPreferences() {
        let settings = WorkspaceBarSettings()
        let monitor = monitor()
        for mode in WorkspaceBarNotchMode.allCases {
            settings.notchMode = mode
            settings.position = .bottom
            let resolved = settings.resolved(for: monitor)
            XCTAssertEqual(resolved.notchMode, .off)
            XCTAssertEqual(settings.notchMode, mode)
            settings.update(
                MonitorBarSettings(monitorName: "External", position: .belowMenuBar), for: monitor
            )
            XCTAssertEqual(settings.resolved(for: monitor).notchMode, mode)
            settings.remove(for: monitor)
        }
        settings.position = .overlappingMenuBar
        settings.update(MonitorBarSettings(monitorName: "External", position: .bottom), for: monitor)
        XCTAssertEqual(settings.resolved(for: monitor).position, .bottom)
        XCTAssertEqual(settings.resolved(for: monitor).notchMode, .off)
    }

    @MainActor
    func testPopupsOpenAboveBottomBarAndStayOnDisplay() {
        let settings = WorkspaceBarSettings()
        settings.position = .bottom
        settings.height = 30
        let monitor = monitor()
        let anchor = HiddenBarPanelController.panelAnchor(
            monitor: monitor, resolved: settings.resolved(for: monitor), barVisible: true
        )
        XCTAssertEqual(anchor.y, monitor.visibleFrame.minY + 30)
        let size = CGSize(width: 300, height: 200)
        let hiddenFrame = HiddenBarPanelController.panelFrame(
            anchor: anchor, size: size, screenVisibleFrame: monitor.visibleFrame, opensUpward: true
        )
        let statsFrame = SystemStatsPopupController.popupFrame(
            anchor: anchor, size: size, screenVisibleFrame: monitor.visibleFrame, opensUpward: true
        )
        XCTAssertEqual(hiddenFrame.minY, anchor.y + 4)
        XCTAssertEqual(statsFrame, hiddenFrame)
        XCTAssertTrue(monitor.visibleFrame.contains(statsFrame))
        let hiddenBarAnchor = HiddenBarPanelController.panelAnchor(
            monitor: monitor, resolved: settings.resolved(for: monitor), barVisible: false
        )
        XCTAssertEqual(hiddenBarAnchor.y, monitor.visibleFrame.maxY)
    }
}
