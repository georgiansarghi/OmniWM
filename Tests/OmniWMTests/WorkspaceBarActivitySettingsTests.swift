// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

final class WorkspaceBarActivitySettingsTests: XCTestCase {
    func testDefaultsAndLegacyConfigLeaveActivityRevealOff() throws {
        let defaults = SettingsExport.defaults()
        XCTAssertEqual(defaults.workspaceBar.activityReveal, .off)
        XCTAssertEqual(defaults.workspaceBar.activityRevealSeconds, 1)
        let data = try SettingsTOMLCodec.encode(defaults)
        let toml = String(decoding: data, as: UTF8.self)
        let legacy = toml.replacingOccurrences(of: "activityReveal = \"off\"\n", with: "")
            .replacingOccurrences(of: "activityRevealSeconds = 1.0\n", with: "")
        XCTAssertNotEqual(toml, legacy)
        XCTAssertFalse(legacy.contains("activityReveal"))
        let decoded = try SettingsTOMLCodec.decode(Data(legacy.utf8))
        XCTAssertEqual(decoded.workspaceBar.activityReveal, .off)
        XCTAssertEqual(decoded.workspaceBar.activityRevealSeconds, 1)
    }

    func testEveryModeAndMonitorOverridesRoundTripThroughTOML() throws {
        for mode in WorkspaceBarActivityReveal.allCases {
            var export = SettingsExport.defaults()
            export.workspaceBar.visibility = .temporary
            export.workspaceBar.activityReveal = mode
            export.workspaceBar.activityRevealSeconds = 1.5
            export.monitorBarSettings = [
                MonitorBarSettings(monitorName: "Off", activityReveal: .off, activityRevealSeconds: 2),
                MonitorBarSettings(monitorName: "Inherited")
            ]
            let data = try SettingsTOMLCodec.encode(export)
            XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
            let decoded = try SettingsTOMLCodec.decode(data)
            XCTAssertEqual(decoded.workspaceBar.activityReveal, mode)
            XCTAssertEqual(decoded.workspaceBar.activityRevealSeconds, 1.5)
            XCTAssertEqual(decoded.monitorBarSettings.map(\.activityReveal), [.off, nil])
            XCTAssertEqual(decoded.monitorBarSettings.map(\.activityRevealSeconds), [2, nil])
        }
    }

    @MainActor
    func testOverrideInheritanceAndAutoHideTogglePreservePreferences() {
        let settings = WorkspaceBarSettings()
        let monitor = Monitor(
            id: .init(displayId: 1), displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 770), hasNotch: false, name: "Test"
        )
        settings.visibility = .temporary
        settings.activityReveal = .workspaceAndColumn
        settings.activityRevealSeconds = 1.5
        settings.update(MonitorBarSettings(monitorName: "Test", activityReveal: .off), for: monitor)
        XCTAssertEqual(settings.resolved(for: monitor).activityReveal, .off)
        XCTAssertEqual(settings.resolved(for: monitor).activityRevealSeconds, 1.5)
        settings.remove(for: monitor)
        settings.visibility = .alwaysVisible
        XCTAssertEqual(settings.resolved(for: monitor).activityReveal, .workspaceAndColumn)
        settings.visibility = .temporary
        XCTAssertEqual(settings.export().activityReveal, .workspaceAndColumn)
        XCTAssertEqual(settings.export().activityRevealSeconds, 1.5)
    }

    @MainActor
    func testDurationsAreFiniteAndBoundedForGlobalAndMonitorSettings() throws {
        for (input, expected) in [(Double.nan, 1.0), (.infinity, 1), (-1, 0.1), (100, 10)] {
            let settings = WorkspaceBarSettings()
            settings.activityRevealSeconds = input
            XCTAssertEqual(settings.activityRevealSeconds, expected)
            var override = MonitorBarSettings(monitorName: "Test")
            override.activityRevealSeconds = input
            settings.monitorOverrides = [override]
            XCTAssertEqual(settings.monitorOverrides[0].activityRevealSeconds, expected)
            var export = SettingsExport.defaults()
            export.workspaceBar.activityRevealSeconds = input
            let decoded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export))
            XCTAssertEqual(decoded.workspaceBar.activityRevealSeconds, expected)
        }
    }
}
