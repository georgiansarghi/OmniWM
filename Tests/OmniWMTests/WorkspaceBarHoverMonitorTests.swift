// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

@MainActor
final class WorkspaceBarHoverMonitorTests: XCTestCase {
    private func target() -> WorkspaceBarHoverTarget {
        WorkspaceBarHoverTarget(
            monitor: Monitor(
                id: .init(displayId: 1), displayId: 1,
                frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
                visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 770), hasNotch: false, name: "Test"
            ),
            frames: [CGRect(x: 400, y: 0, width: 200, height: 32)],
            position: .bottom, isVisible: false, isPinned: false
        )
    }

    func testRevealAndHideNotifySynchronouslyWithoutDuplicateNotifications() {
        let monitor = WorkspaceBarHoverMonitor()
        defer { monitor.stop() }
        let target = target()
        monitor.targets = { [target] }
        monitor.pointer = { CGPoint(x: 500, y: 1) }
        var callbacks = 0
        monitor.onRevealChanged = { callbacks += 1 }
        monitor.start()
        XCTAssertEqual(monitor.state.revealed, [target.id])
        XCTAssertEqual(callbacks, 1)
        monitor.refresh()
        XCTAssertEqual(callbacks, 1)
        monitor.pointer = { CGPoint(x: 500, y: 400) }
        monitor.refresh()
        XCTAssertTrue(monitor.state.revealed.isEmpty)
        XCTAssertEqual(callbacks, 2)
    }

    func testStopResetsAndRestartUsesCurrentPointer() {
        let monitor = WorkspaceBarHoverMonitor()
        defer { monitor.stop() }
        let target = target()
        monitor.targets = { [target] }
        monitor.pointer = { CGPoint(x: 500, y: 1) }
        var callbacks = 0
        monitor.onRevealChanged = { callbacks += 1 }
        monitor.start()
        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
        XCTAssertTrue(monitor.state.revealed.isEmpty)
        XCTAssertEqual(callbacks, 2)
        monitor.refresh()
        XCTAssertEqual(callbacks, 2)
        monitor.pointer = { CGPoint(x: 500, y: 400) }
        monitor.start()
        XCTAssertTrue(monitor.state.revealed.isEmpty)
        XCTAssertEqual(callbacks, 2)
    }
}
