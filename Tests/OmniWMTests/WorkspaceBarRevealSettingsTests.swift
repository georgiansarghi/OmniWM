// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

final class WorkspaceBarRevealSettingsTests: XCTestCase {
    func testDefaultsRoundTrip() throws {
        XCTAssertEqual(SettingsExport.defaults().workspaceBar.revealModifier, .off)
        XCTAssertEqual(SettingsExport.defaults().workspaceBar.revealHoldMilliseconds, 200)

        let data = try SettingsTOMLCodec.encode(.defaults())
        let toml = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(toml.contains("revealModifier = \"off\""))
        XCTAssertTrue(toml.contains("revealHoldMilliseconds = 200"))

        let decoded = try SettingsTOMLCodec.decode(data)
        XCTAssertEqual(decoded.workspaceBar.revealModifier, .off)
        XCTAssertEqual(decoded.workspaceBar.revealHoldMilliseconds, 200)
    }

    func testNonDefaultRoundTrip() throws {
        var export = SettingsExport.defaults()
        export.workspaceBar.revealModifier = .controlOptionCommand
        export.workspaceBar.revealHoldMilliseconds = 350

        let data = try SettingsTOMLCodec.encode(export)
        let toml = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(toml.contains("revealModifier = \"controlOptionCommand\""))
        XCTAssertTrue(toml.contains("revealHoldMilliseconds = 350"))

        let decoded = try SettingsTOMLCodec.decode(data)
        XCTAssertEqual(decoded.workspaceBar.revealModifier, .controlOptionCommand)
        XCTAssertEqual(decoded.workspaceBar.revealHoldMilliseconds, 350)
        XCTAssertEqual(decoded.workspaceBar.visibility, .alwaysVisible)
        XCTAssertTrue(decoded.workspaceBar.revealOnHover)
    }

    func testLegacyModifierSettingsKeepTheirVisibilityAfterLoadAndSave() throws {
        for modifier in [WorkspaceBarRevealModifier.off, .option] {
            var export = SettingsExport.defaults()
            export.workspaceBar.revealModifier = modifier
            export.monitorBarSettings = [MonitorBarSettings(monitorName: "Inherited")]
            let text = String(decoding: try SettingsTOMLCodec.encode(export), as: UTF8.self)
                .replacingOccurrences(of: "visibility = \"alwaysVisible\"\n", with: "")
                .replacingOccurrences(of: "revealOnHover = true\n", with: "")
            for schema in [2, 3] {
                let legacy = schema == 3 ? text : "monitorRoutingOverrides = []\n" + text
                    .replacingOccurrences(of: "schemaVersion = 3", with: "schemaVersion = 2")
                    .replacingOccurrences(of: "arrangements = []\n", with: "")
                let data = Data(legacy.utf8)
                let decoded = try SettingsTOMLCodec.decode(data)
                XCTAssertEqual(decoded.workspaceBar.visibility, modifier == .off ? .alwaysVisible : .temporary)
                XCTAssertEqual(decoded.workspaceBar.revealOnHover, modifier == .off)
                XCTAssertEqual(decoded.workspaceBar.activityReveal, .off)
                XCTAssertNil(decoded.monitorBarSettings[0].visibility)
                XCTAssertNil(decoded.monitorBarSettings[0].revealOnHover)
                let saved = try SettingsTOMLCodec.encode(decoded, preservingUnknownKeysFrom: data)
                XCTAssertEqual(try SettingsTOMLCodec.decode(saved).workspaceBar, decoded.workspaceBar)
            }
        }
    }

    @MainActor
    func testApplyExportClampsDelay() {
        let settings = makeSettingsStore()
        var export = SettingsExport.defaults()

        export.workspaceBar.revealModifier = .option
        export.workspaceBar.revealHoldMilliseconds = -50
        settings.applyExport(export)
        XCTAssertEqual(settings.workspaceBar.revealModifier, .option)
        XCTAssertEqual(settings.workspaceBar.revealHoldMilliseconds, 0)

        export.workspaceBar.revealHoldMilliseconds = 5000
        settings.applyExport(export)
        XCTAssertEqual(settings.workspaceBar.revealHoldMilliseconds, 1000)
    }

    @MainActor
    func testRevealModeIsOverlayOnlyAndOffModePreservesReservation() {
        let settings = makeSettingsStore()
        settings.workspaceBar.visibility = .temporary
        settings.workspaceBar.revealOnHover = false
        settings.workspaceBar.enabled = true
        settings.workspaceBar.reserveLayoutSpace = true
        settings.workspaceBar.height = 24
        settings.workspaceBar.revealModifier = .option
        let controller = WMController(settings: settings)
        let monitor = Monitor(
            id: .init(displayId: 1),
            displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860),
            hasNotch: false,
            name: "Built-in"
        )

        XCTAssertFalse(controller.isWorkspaceBarVisible(on: monitor))
        XCTAssertEqual(
            controller.insetWorkingFrame(for: monitor),
            CGRect(x: 5, y: 5, width: 1430, height: 850)
        )
        XCTAssertEqual(controller.fullscreenLayoutFrame(for: monitor), monitor.visibleFrame)

        controller.setWorkspaceBarRevealHeld(true)
        XCTAssertTrue(controller.isWorkspaceBarVisible(on: monitor))
        XCTAssertEqual(
            controller.insetWorkingFrame(for: monitor),
            CGRect(x: 5, y: 5, width: 1430, height: 850)
        )
        XCTAssertEqual(controller.fullscreenLayoutFrame(for: monitor), monitor.visibleFrame)

        settings.workspaceBar.visibility = .alwaysVisible
        controller.setWorkspaceBarRevealHeld(false)
        XCTAssertTrue(controller.isWorkspaceBarVisible(on: monitor))
        XCTAssertEqual(
            controller.insetWorkingFrame(for: monitor),
            CGRect(x: 5, y: 5, width: 1430, height: 831)
        )
        XCTAssertEqual(
            controller.fullscreenLayoutFrame(for: monitor),
            CGRect(x: 0, y: 0, width: 1440, height: 836)
        )
    }

    @MainActor
    func testRevealModeKeepsFullscreenOuterGapsButDropsReservation() {
        let settings = makeSettingsStore()
        settings.gaps.outerGapLeft = 12
        settings.gaps.outerGapRight = 12
        settings.gaps.outerGapTop = 46
        settings.gaps.outerGapBottom = 14
        settings.gaps.fullscreenUsesOuterGaps = true
        settings.workspaceBar.visibility = .temporary
        settings.workspaceBar.revealOnHover = false
        settings.workspaceBar.enabled = true
        settings.workspaceBar.reserveLayoutSpace = true
        settings.workspaceBar.height = 24
        settings.workspaceBar.revealModifier = .option
        let controller = WMController(settings: settings)
        let monitor = Monitor(
            id: .init(displayId: 1),
            displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860),
            hasNotch: false,
            name: "Built-in"
        )

        let overlayFrame = CGRect(x: 12, y: 14, width: 1416, height: 840)
        XCTAssertEqual(controller.insetWorkingFrame(for: monitor), overlayFrame)
        XCTAssertEqual(controller.fullscreenLayoutFrame(for: monitor), overlayFrame)

        controller.setWorkspaceBarRevealHeld(true)
        XCTAssertEqual(controller.insetWorkingFrame(for: monitor), overlayFrame)
        XCTAssertEqual(controller.fullscreenLayoutFrame(for: monitor), overlayFrame)

        settings.workspaceBar.visibility = .alwaysVisible
        controller.setWorkspaceBarRevealHeld(false)
        let reservedFrame = CGRect(x: 12, y: 14, width: 1416, height: 816)
        XCTAssertEqual(controller.insetWorkingFrame(for: monitor), reservedFrame)
        XCTAssertEqual(controller.fullscreenLayoutFrame(for: monitor), reservedFrame)
    }

    private func defaultsDroppingLines(containing fragments: String...) throws -> Data {
        let toml = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        let lines = toml.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            !fragments.contains { line.contains($0) }
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    @MainActor
    private func makeSettingsStore() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMWorkspaceBarRevealTests-\(UUID().uuidString)", isDirectory: true)
        return SettingsStore(
            persistence: SettingsFilePersistence(
                directory: root.appendingPathComponent("config", isDirectory: true),
                startWatching: false,
                deferSaves: false
            ),
            runtimeState: RuntimeStateStore(
                directory: root.appendingPathComponent("state", isDirectory: true),
                deferSaves: false
            ),
            autosaveEnabled: false
        )
    }
}
