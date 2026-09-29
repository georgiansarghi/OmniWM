// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

final class WorkspaceBarActivityStateTests: XCTestCase {
    private let first = WorkspaceDescriptor.ID()
    private let second = WorkspaceDescriptor.ID()
    private let monitor = Monitor.ID(displayId: 1)

    private func target(
        workspace: WorkspaceDescriptor.ID? = nil, column: NodeId? = nil, token: WindowToken? = nil,
        mode: WorkspaceBarActivityReveal = .workspaceAndColumn, allowed: Bool = true,
        duration: Double = 1, display: CGDirectDisplayID = 1
    ) -> WorkspaceBarActivityTarget {
        WorkspaceBarActivityTarget(
            monitorId: .init(displayId: display), workspaceId: workspace ?? first,
            columnId: column, focusedToken: token, allowed: allowed, mode: mode, duration: duration
        )
    }

    func testInitialObservationAndNoOpsDoNotRevealOrExtendDeadline() {
        var state = WorkspaceBarActivityState()
        state.update(targets: [target()], now: 0)
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: [target(workspace: second)], now: 1)
        XCTAssertEqual(state.revealed, [monitor])
        XCTAssertEqual(state.nextDeadline, 2)
        state.update(targets: [target(workspace: second)], now: 1.5)
        XCTAssertEqual(state.nextDeadline, 2)
        state.update(targets: [target(workspace: second)], now: 2)
        XCTAssertTrue(state.revealed.isEmpty)
    }

    func testRepeatedChangesExtendFromLastChangeWithoutStackingDurations() {
        var state = WorkspaceBarActivityState()
        state.update(targets: [target()], now: 0)
        state.update(targets: [target(workspace: second)], now: 1)
        state.update(targets: [target()], now: 1.8)
        XCTAssertEqual(state.nextDeadline, 2.8)
        state.update(targets: [target()], now: 2.1)
        XCTAssertEqual(state.revealed, [monitor])
        state.update(targets: [target()], now: 2.8)
        XCTAssertTrue(state.revealed.isEmpty)
    }

    func testModesDistinguishWorkspaceColumnAndWindowChanges() {
        let columnA = NodeId(), columnB = NodeId()
        let tokenA = WindowToken(pid: 1, windowId: 1), tokenB = WindowToken(pid: 1, windowId: 2)
        for mode in WorkspaceBarActivityReveal.allCases {
            var state = WorkspaceBarActivityState()
            state.update(targets: [target(column: columnA, token: tokenA, mode: mode)], now: 0)
            state.update(targets: [target(column: columnA, token: tokenB, mode: mode)], now: 1)
            XCTAssertEqual(state.revealed.contains(monitor), mode == .focus, "\(mode)")
            state.update(targets: [target(column: columnB, token: tokenA, mode: mode)], now: 3)
            XCTAssertEqual(state.revealed.contains(monitor), mode == .focus || mode == .workspaceAndColumn, "\(mode)")
            state.update(targets: [target(workspace: second, mode: mode)], now: 5)
            XCTAssertEqual(state.revealed.contains(monitor), mode != .off, "\(mode)")
        }
    }

    func testFocusLossAndInitialColumnCreationDoNotReveal() {
        var state = WorkspaceBarActivityState()
        state.update(targets: [target()], now: 0)
        state.update(targets: [target(column: NodeId())], now: 1)
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: [target(token: WindowToken(pid: 1, windowId: 1), mode: .focus)], now: 2)
        state.update(targets: [target(mode: .focus)], now: 3)
        XCTAssertTrue(state.revealed.isEmpty)
    }

    func testDisplayDeadlinesAreIndependentAndDisconnectCancels() {
        var state = WorkspaceBarActivityState()
        state.update(targets: [target(), target(duration: 2, display: 2)], now: 0)
        state.update(targets: [target(workspace: second), target(duration: 2, display: 2)], now: 1)
        XCTAssertEqual(state.revealed, [monitor])
        state.update(targets: [target(workspace: second), target(workspace: second, duration: 2, display: 2)], now: 1.5)
        XCTAssertEqual(state.deadlines[.init(displayId: 2)], 3.5)
        state.update(targets: [target(workspace: second), target(workspace: second, duration: 2, display: 2)], now: 2)
        XCTAssertEqual(state.revealed, [.init(displayId: 2)])
        state.update(targets: [target(workspace: second)], now: 2.1)
        XCTAssertNil(state.nextDeadline)
    }

    func testSuppressionAndSettingsChangesCancelAndRebaselineInsteadOfReplaying() {
        var state = WorkspaceBarActivityState()
        state.update(targets: [target()], now: 0)
        state.update(targets: [target(workspace: second)], now: 1)
        state.update(targets: [target(allowed: false)], now: 1.1)
        XCTAssertNil(state.nextDeadline)
        state.update(targets: [target(workspace: second)], now: 1.2)
        XCTAssertNil(state.nextDeadline)
        state.update(targets: [target()], now: 1.3)
        XCTAssertNotNil(state.nextDeadline)
        state.update(targets: [target(mode: .workspace)], now: 1.4)
        XCTAssertNil(state.nextDeadline)
        state.update(targets: [target(workspace: second, mode: .workspace)], now: 1.5)
        XCTAssertNotNil(state.nextDeadline)
        state.update(targets: [target(mode: .workspace, duration: 2)], now: 1.6)
        XCTAssertNil(state.nextDeadline)
    }

    func testResetClearsDeadlineAndBaseline() {
        var state = WorkspaceBarActivityState()
        state.update(targets: [target()], now: 0)
        state.update(targets: [target(workspace: second)], now: 1)
        state.reset()
        XCTAssertTrue(state.revealed.isEmpty)
        XCTAssertNil(state.nextDeadline)
        state.update(targets: [target()], now: 1.1)
        XCTAssertTrue(state.revealed.isEmpty)
    }
}
