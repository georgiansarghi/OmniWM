// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

final class WorkspaceBarAutoHideSettingsTests: XCTestCase {
    func testDefaultsAndLegacyFilesDoNotEnableAutoHide() throws {
        let defaults = SettingsExport.defaults()
        XCTAssertFalse(defaults.workspaceBar.autoHide)
        let data = try SettingsTOMLCodec.encode(defaults)
        XCTAssertFalse(try SettingsTOMLCodec.decode(data).workspaceBar.autoHide)
        let toml = String(decoding: data, as: UTF8.self)
        let section = try XCTUnwrap(toml.range(of: "[workspaceBar]\n"))
        let key = try XCTUnwrap(toml.range(of: "autoHide = false\n", range: section.upperBound ..< toml.endIndex))
        var old = toml
        old.removeSubrange(key)
        XCTAssertNotEqual(old, toml)
        XCTAssertFalse(try SettingsTOMLCodec.decode(Data(old.utf8)).workspaceBar.autoHide)
    }

    func testGlobalAndPerDisplayValuesRoundTrip() throws {
        var export = SettingsExport.defaults()
        export.workspaceBar.autoHide = true
        export.monitorBarSettings = [
            MonitorBarSettings(monitorName: "Off", autoHide: false),
            MonitorBarSettings(monitorName: "On", autoHide: true),
            MonitorBarSettings(monitorName: "Inherited")
        ]
        let data = try SettingsTOMLCodec.encode(export)
        XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        let decoded = try SettingsTOMLCodec.decode(data)
        XCTAssertTrue(decoded.workspaceBar.autoHide)
        XCTAssertEqual(decoded.monitorBarSettings.map(\.autoHide), [false, true, nil])
    }

    @MainActor
    func testOverridesAndOverlayReservationApplyToEveryPosition() {
        let settings = WorkspaceBarSettings()
        settings.autoHide = true
        settings.reserveLayoutSpace = true
        let monitor = Monitor(
            id: .init(displayId: 1), displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860), hasNotch: false, name: "Test"
        )
        for position in WorkspaceBarPosition.allCases {
            settings.position = position
            let resolved = settings.resolved(for: monitor)
            XCTAssertTrue(resolved.autoHide)
            for visible in [false, true] {
                XCTAssertEqual(WorkspaceBarGeometry.resolve(
                    monitor: monitor, resolved: resolved, isVisible: visible
                ).reservedInsets, .zero)
            }
        }
        settings.update(MonitorBarSettings(monitorName: "Test", autoHide: false), for: monitor)
        XCTAssertFalse(settings.resolved(for: monitor).autoHide)
        settings.remove(for: monitor)
        XCTAssertTrue(settings.resolved(for: monitor).autoHide)
        XCTAssertTrue(settings.export().autoHide)
    }
}
