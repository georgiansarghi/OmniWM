// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import CoreGraphics
@testable import OmniWM
import XCTest

final class WorkspaceBarHoverStateTests: XCTestCase {
    private let monitor = Monitor(
        id: .init(displayId: 1), displayId: 1,
        frame: CGRect(x: -1000, y: -800, width: 1000, height: 800),
        visibleFrame: CGRect(x: -1000, y: -740, width: 1000, height: 710),
        hasNotch: false, name: "Test"
    )
    private let frame = CGRect(x: -600, y: -740, width: 200, height: 32)
    private let near = CGPoint(x: -500, y: -735)
    private let away = CGPoint(x: -100, y: -200)

    private func target(visible: Bool = false, pinned: Bool = false) -> WorkspaceBarHoverTarget {
        WorkspaceBarHoverTarget(
            monitor: monitor, frames: [frame], position: .bottom, isVisible: visible, isPinned: pinned
        )
    }

    func testRevealAndHideBothHappenOnTheFirstPointerUpdate() {
        var state = WorkspaceBarHoverState()
        state.update(targets: [target()], pointer: near)
        XCTAssertEqual(state.revealed, [monitor.id])
        state.update(targets: [target(visible: true)], pointer: away)
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: [target()], pointer: near)
        XCTAssertEqual(state.revealed, [monitor.id])
    }

    func testRetentionMarginPreventsFlickerWithoutDelayingHide() {
        var state = WorkspaceBarHoverState()
        state.update(targets: [target()], pointer: near)
        let margin = CGPoint(x: frame.minX - 15, y: frame.midY)
        state.update(targets: [target(visible: true)], pointer: margin)
        XCTAssertEqual(state.revealed, [monitor.id])
        state.update(targets: [target(visible: true)], pointer: away)
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: [target()], pointer: margin)
        XCTAssertTrue(state.revealed.isEmpty)
    }

    func testPopupPinsVisibleBarButDoesNotRevealHiddenBar() {
        var state = WorkspaceBarHoverState()
        state.update(targets: [target(pinned: true)], pointer: away)
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: [target(visible: true, pinned: true)], pointer: away)
        XCTAssertEqual(state.revealed, [monitor.id])
        state.update(targets: [target(visible: true)], pointer: away)
        XCTAssertTrue(state.revealed.isEmpty)
    }

    func testOpeningPopupWhileLeavingBarKeepsItRevealed() {
        var state = WorkspaceBarHoverState()
        state.update(targets: [target()], pointer: near)
        state.update(targets: [target(visible: true, pinned: true)], pointer: away)
        XCTAssertEqual(state.revealed, [monitor.id])
    }

    func testRemovingDisplayOrDisablingEligibilityClearsRevealImmediately() {
        var state = WorkspaceBarHoverState()
        state.update(targets: [target()], pointer: near)
        state.update(targets: [], pointer: near)
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: [target(visible: true)], pointer: near)
        XCTAssertFalse(state.revealed.isEmpty)
        state.reset()
        XCTAssertTrue(state.revealed.isEmpty)
    }

    func testDisplaysRevealIndependentlyWithoutTriggeringTheWholeEdge() {
        let other = Monitor(
            id: .init(displayId: 2), displayId: 2,
            frame: monitor.frame.offsetBy(dx: 1000, dy: 0),
            visibleFrame: monitor.visibleFrame.offsetBy(dx: 1000, dy: 0), hasNotch: false, name: "Other"
        )
        let otherTarget = WorkspaceBarHoverTarget(
            monitor: other, frames: [frame.offsetBy(dx: 1000, dy: 0)], position: .bottom,
            isVisible: false, isPinned: false
        )
        var state = WorkspaceBarHoverState()
        let targets = [target(), otherTarget]
        state.update(targets: targets, pointer: CGPoint(x: -950, y: -740))
        XCTAssertTrue(state.revealed.isEmpty)
        state.update(targets: targets, pointer: near)
        XCTAssertEqual(state.revealed, [monitor.id])
        let otherPointer = CGPoint(x: near.x + 1000, y: near.y)
        state.update(targets: targets, pointer: otherPointer)
        XCTAssertEqual(state.revealed, [other.id])
    }

    func testAllEdgesReachTheDisplayBoundaryWithOffsetsAndStayOnTheirDisplay() {
        let floatingFrame = CGRect(x: -600, y: -500, width: 200, height: 32)
        let cases: [(WorkspaceBarPosition, CGPoint)] = [
            (.overlappingMenuBar, CGPoint(x: -500, y: -1)),
            (.belowMenuBar, CGPoint(x: -500, y: -1)),
            (.bottom, CGPoint(x: -500, y: -740)),
            (.left, CGPoint(x: -1000, y: -490)),
            (.right, CGPoint(x: -1, y: -490))
        ]
        for (position, point) in cases {
            let target = WorkspaceBarHoverTarget(
                monitor: monitor, frames: [floatingFrame], position: position, isVisible: false, isPinned: false
            )
            XCTAssertTrue(target.activationRegions.contains { $0.contains(point) }, "\(position)")
            XCTAssertTrue(target.activationRegions.allSatisfy { monitor.frame.contains($0) })
        }
    }

    func testAssociatedFallbackIconKeepsVisibleBarOpenButCannotRevealItFromElsewhere() {
        let icon = CGRect(x: frame.minX - 40, y: frame.minY, width: 32, height: 32)
        var state = WorkspaceBarHoverState()
        let hidden = WorkspaceBarHoverTarget(
            monitor: monitor, frames: [frame], position: .bottom, isVisible: false, isPinned: false,
            associatedFrames: [icon]
        )
        let pointer = CGPoint(x: icon.midX, y: icon.midY)
        state.update(targets: [hidden], pointer: pointer)
        XCTAssertTrue(state.revealed.isEmpty)
        let visible = WorkspaceBarHoverTarget(
            monitor: monitor, frames: [frame], position: .bottom, isVisible: true, isPinned: false,
            associatedFrames: [icon]
        )
        state.update(targets: [visible], pointer: pointer)
        XCTAssertEqual(state.revealed, [monitor.id])
    }

    func testSplitIslandsDoNotActivateInTheNotchGap() {
        let target = WorkspaceBarHoverTarget(
            monitor: monitor,
            frames: [
                CGRect(x: -900, y: -30, width: 200, height: 24),
                CGRect(x: -300, y: -30, width: 200, height: 24)
            ],
            position: .overlappingMenuBar, isVisible: false, isPinned: false
        )
        XCTAssertFalse(target.activationRegions.contains { $0.contains(CGPoint(x: -500, y: -1)) })
        XCTAssertTrue(target.activationRegions.contains { $0.contains(CGPoint(x: -800, y: -1)) })
    }
}
