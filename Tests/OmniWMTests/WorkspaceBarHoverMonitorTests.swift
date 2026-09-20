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

    func testStationaryPointerRevealsOnDeadlineAndStopResets() async {
        let monitor = WorkspaceBarHoverMonitor()
        let target = target()
        monitor.targets = { [target] }
        monitor.pointer = { CGPoint(x: 500, y: 1) }
        let revealed = expectation(description: "Reveal without another mouse event")
        monitor.onRevealChanged = { if !monitor.state.revealed.isEmpty { revealed.fulfill() } }
        monitor.start()
        await fulfillment(of: [revealed], timeout: 2)
        XCTAssertEqual(monitor.state.revealed, [target.id])
        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
        XCTAssertTrue(monitor.state.revealed.isEmpty)
        XCTAssertNil(monitor.state.nextDeadline)
        monitor.onRevealChanged = {}
    }

    func testStopAndRestartCannotFireTheOldDeadline() async throws {
        let monitor = WorkspaceBarHoverMonitor()
        defer { monitor.stop() }
        let target = target()
        monitor.targets = { [target] }
        monitor.pointer = { CGPoint(x: 500, y: 1) }
        var callbacks = 0
        monitor.onRevealChanged = { callbacks += 1 }
        monitor.start()
        monitor.stop()
        monitor.pointer = { CGPoint(x: 500, y: 400) }
        monitor.start()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(monitor.state.revealed.isEmpty)
        XCTAssertEqual(callbacks, 0)
        XCTAssertNil(monitor.state.nextDeadline)
    }
}
