// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

final class WorkspaceBarAutoHideSettingsTests: XCTestCase {
    func testDefaultsAreAlwaysVisibleWithIndependentHoverPreference() throws {
        let defaults = SettingsExport.defaults()
        XCTAssertEqual(defaults.workspaceBar.visibility, .alwaysVisible)
        XCTAssertTrue(defaults.workspaceBar.revealOnHover)
        let decoded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(defaults))
        XCTAssertEqual(decoded.workspaceBar.visibility, .alwaysVisible)
        XCTAssertTrue(decoded.workspaceBar.revealOnHover)
    }

    func testLegacyAutoHideAndModifierOnlyModesPreserveBehavior() throws {
        for autoHide in [nil, false, true] as [Bool?] {
            for modifier in [WorkspaceBarRevealModifier.off, .option] {
                let data = try legacyData(autoHide: autoHide, modifier: modifier)
                let decoded = try SettingsTOMLCodec.decode(data)
                XCTAssertEqual(
                    decoded.workspaceBar.visibility,
                    autoHide == true || modifier != .off ? .temporary : .alwaysVisible
                )
                XCTAssertEqual(decoded.workspaceBar.revealOnHover, autoHide == true || modifier == .off)
                XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
            }
        }
    }

    func testLegacyDisplayOverridesPreserveModifierInteractionAndInheritance() throws {
        for modifier in [WorkspaceBarRevealModifier.off, .option] {
            let data = try legacyData(autoHide: true, modifier: modifier, withOverrides: true)
            let decoded = try SettingsTOMLCodec.decode(data)
            XCTAssertEqual(
                decoded.monitorBarSettings.map(\.visibility),
                [modifier == .off ? .alwaysVisible : .temporary, .temporary, nil]
            )
            XCTAssertEqual(decoded.monitorBarSettings.map(\.revealOnHover), [false, true, nil])
            XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        }
    }

    func testNewKeysWinAndSavingRetiresAliasWithoutDroppingUnknownFields() throws {
        var export = SettingsExport.defaults()
        export.workspaceBar.visibility = .alwaysVisible
        export.workspaceBar.revealOnHover = false
        export.workspaceBar.revealModifier = .option
        let canonical = String(decoding: try SettingsTOMLCodec.encode(export), as: UTF8.self)
        let legacy = Data(canonical.replacingOccurrences(
            of: "[workspaceBar]\n", with: "[workspaceBar]\nautoHide = true\nfutureOption = 42\n"
        ).utf8)
        let decoded = try SettingsTOMLCodec.decode(legacy)
        XCTAssertEqual(decoded.workspaceBar.visibility, .alwaysVisible)
        XCTAssertFalse(decoded.workspaceBar.revealOnHover)
        XCTAssertEqual(SettingsTOMLCodec.unknownKeyPaths(in: legacy), ["workspaceBar.futureOption"])
        let saved = String(
            decoding: try SettingsTOMLCodec.encode(decoded, preservingUnknownKeysFrom: legacy),
            as: UTF8.self
        )
        XCTAssertFalse(try barSection(saved).contains("autoHide"))
        XCTAssertTrue(try barSection(saved).contains("futureOption = 42"))
        XCTAssertEqual(try SettingsTOMLCodec.decode(Data(saved.utf8)).workspaceBar, decoded.workspaceBar)
    }

    func testLegacyModifierOnlyScopesDoNotAcquireDormantActivityAfterLoadOrSave() throws {
        for autoHide in [nil, false, true] as [Bool?] {
            for schema in [2, 3] {
                let original = try legacyData(
                    autoHide: autoHide, modifier: .option, withOverrides: true, activity: .workspace
                )
                var text = String(decoding: original, as: UTF8.self)
                if schema == 2 {
                    text = "monitorRoutingOverrides = []\n" + text
                        .replacingOccurrences(of: "schemaVersion = 3", with: "schemaVersion = 2")
                        .replacingOccurrences(of: "arrangements = []\n", with: "")
                }
                let data = Data(text.utf8)
                let decoded = try SettingsTOMLCodec.decode(data)
                let effective = decoded.monitorBarSettings
                    .map { $0.activityReveal ?? decoded.workspaceBar.activityReveal }
                XCTAssertEqual(decoded.workspaceBar.activityReveal, autoHide == true ? .workspace : .off)
                XCTAssertEqual(effective, [.off, .workspace, autoHide == true ? .workspace : .off])
                let unknown = SettingsTOMLCodec.unknownKeyPaths(in: data)
                XCTAssertFalse(unknown.contains { $0.contains("autoHide") })
                if schema == 3 { XCTAssertTrue(unknown.isEmpty) }
                let saved = try SettingsTOMLCodec.encode(decoded, preservingUnknownKeysFrom: data)
                let reloaded = try SettingsTOMLCodec.decode(saved)
                XCTAssertEqual(reloaded.workspaceBar, decoded.workspaceBar)
                XCTAssertEqual(reloaded.monitorBarSettings, decoded.monitorBarSettings)
            }
        }
    }

    @MainActor
    func testLegacyInactiveActivityKeepsInheritedOverridesInheritedAfterGlobalChangesAndSave() throws {
        let monitor = Monitor(
            id: .init(displayId: 1), displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 770), hasNotch: false, name: "Inherited"
        )
        for autoHide in [nil, false, true] as [Bool?] {
            let data = try legacyData(
                autoHide: autoHide, modifier: .option, withOverrides: true,
                activity: autoHide == true ? .off : .workspace
            )
            var decoded = try SettingsTOMLCodec.decode(data)
            XCTAssertNil(decoded.monitorBarSettings[2].activityReveal)
            // Explicit legacy autoHide=false also needs no override when the global activity trigger is off.
            XCTAssertNil(decoded.monitorBarSettings[0].activityReveal)
            let settings = WorkspaceBarSettings()
            settings.applyAppearance(decoded.workspaceBar, monitorOverrides: decoded.monitorBarSettings)
            settings.activityReveal = .focus
            XCTAssertEqual(settings.resolved(for: monitor).activityReveal, .focus)
            decoded.workspaceBar = settings.export()
            decoded.monitorBarSettings = settings.monitorOverrides
            let reloaded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(
                decoded,
                preservingUnknownKeysFrom: data
            ))
            XCTAssertNil(reloaded.monitorBarSettings[2].activityReveal)
            let restored = WorkspaceBarSettings()
            restored.applyAppearance(reloaded.workspaceBar, monitorOverrides: reloaded.monitorBarSettings)
            XCTAssertEqual(restored.resolved(for: monitor).activityReveal, .focus)
        }
    }

    func testMigrationDoesNotHideInvalidDormantActivityValues() throws {
        let original = String(decoding: try legacyData(
            autoHide: false, modifier: .option, withOverrides: true, activity: .workspace
        ), as: UTF8.self)
        for value in ["42", "\"unknown\""] {
            let global = original.replacingOccurrences(
                of: "activityReveal = \"workspace\"",
                with: "activityReveal = \(value)"
            )
            XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(global.utf8)))
            let monitor = original.replacingOccurrences(
                of: "monitorName = \"Off\"", with: "monitorName = \"Off\"\nactivityReveal = \(value)"
            )
            XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(monitor.utf8)))
        }
    }

    func testExplicitNewActivityOnlyModesAreNotSubjectToLegacyActivityGating() throws {
        var export = SettingsExport.defaults()
        export.workspaceBar.visibility = .temporary
        export.workspaceBar.revealOnHover = false
        export.workspaceBar.revealModifier = .option
        export.workspaceBar.activityReveal = .workspace
        export.monitorBarSettings = [
            MonitorBarSettings(
                monitorName: "Explicit",
                visibility: .temporary,
                revealOnHover: false,
                activityReveal: .focus
            )
        ]
        let text = String(decoding: try SettingsTOMLCodec.encode(export), as: UTF8.self)
            .replacingOccurrences(of: "[workspaceBar]\n", with: "[workspaceBar]\nautoHide = false\n")
            .replacingOccurrences(
                of: "monitorName = \"Explicit\"",
                with: "monitorName = \"Explicit\"\nautoHide = false"
            )
        let decoded = try SettingsTOMLCodec.decode(Data(text.utf8))
        XCTAssertEqual(decoded.workspaceBar.activityReveal, .workspace)
        XCTAssertFalse(decoded.workspaceBar.revealOnHover)
        XCTAssertEqual(decoded.monitorBarSettings.first?.activityReveal, .focus)
        XCTAssertEqual(decoded.monitorBarSettings.first?.revealOnHover, false)
    }

    func testInvalidLegacyBooleanIsNotSilentlyIgnored() throws {
        let data = try legacyData(autoHide: true, modifier: .off)
        let toml = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "autoHide = true", with: "autoHide = \"yes\"")
        XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(toml.utf8)))
    }

    @MainActor
    func testOverridesRoundTripAndTemporaryModeNeverReservesSpace() throws {
        let settings = WorkspaceBarSettings()
        settings.visibility = .temporary
        settings.revealOnHover = false
        settings.reserveLayoutSpace = true
        let monitor = Monitor(
            id: .init(displayId: 1), displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860), hasNotch: false, name: "Test"
        )
        for position in WorkspaceBarPosition.allCases {
            settings.position = position
            let resolved = settings.resolved(for: monitor)
            XCTAssertEqual(resolved.visibility, .temporary)
            XCTAssertFalse(resolved.revealOnHover)
            for visible in [false, true] {
                XCTAssertEqual(WorkspaceBarGeometry.resolve(
                    monitor: monitor, resolved: resolved, isVisible: visible
                ).reservedInsets, .zero)
            }
        }
        settings.update(
            MonitorBarSettings(monitorName: "Test", visibility: .alwaysVisible, revealOnHover: true),
            for: monitor
        )
        XCTAssertEqual(settings.resolved(for: monitor).visibility, .alwaysVisible)
        XCTAssertTrue(settings.resolved(for: monitor).revealOnHover)
        var export = SettingsExport.defaults()
        export.workspaceBar = settings.export()
        export.monitorBarSettings = settings.monitorOverrides
        let data = try SettingsTOMLCodec.encode(export)
        XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        let decoded = try SettingsTOMLCodec.decode(data)
        XCTAssertEqual(decoded.workspaceBar.visibility, .temporary)
        XCTAssertFalse(decoded.workspaceBar.revealOnHover)
        XCTAssertEqual(decoded.monitorBarSettings.first?.visibility, .alwaysVisible)
        XCTAssertEqual(decoded.monitorBarSettings.first?.revealOnHover, true)
        settings.remove(for: monitor)
        XCTAssertEqual(settings.resolved(for: monitor).visibility, .temporary)
        XCTAssertFalse(settings.resolved(for: monitor).revealOnHover)
    }

    private func legacyData(
        autoHide: Bool?, modifier: WorkspaceBarRevealModifier, withOverrides: Bool = false,
        activity: WorkspaceBarActivityReveal = .off
    ) throws -> Data {
        var export = SettingsExport.defaults()
        export.workspaceBar.revealModifier = modifier
        export.workspaceBar.activityReveal = activity
        if withOverrides {
            export.monitorBarSettings = [
                MonitorBarSettings(monitorName: "Off"), MonitorBarSettings(monitorName: "On"),
                MonitorBarSettings(monitorName: "Inherited")
            ]
        }
        var toml = String(decoding: try SettingsTOMLCodec.encode(export), as: UTF8.self)
        let section = try barSection(toml)
        var oldSection = section.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("visibility =") && !$0.hasPrefix("revealOnHover =") }
            .joined(separator: "\n")
        if let autoHide { oldSection = "autoHide = \(autoHide)\n" + oldSection }
        toml = toml.replacingOccurrences(of: section, with: oldSection)
        if withOverrides {
            toml = toml.replacingOccurrences(
                of: "monitorName = \"Off\"",
                with: "monitorName = \"Off\"\nautoHide = false"
            )
            .replacingOccurrences(of: "monitorName = \"On\"", with: "monitorName = \"On\"\nautoHide = true")
        }
        return Data(toml.utf8)
    }

    private func barSection(_ toml: String) throws -> String {
        let start = try XCTUnwrap(toml.range(of: "[workspaceBar]\n")).upperBound
        let end = toml.range(of: "\n[", range: start ..< toml.endIndex)?.lowerBound ?? toml.endIndex
        return String(toml[start ..< end])
    }
}
