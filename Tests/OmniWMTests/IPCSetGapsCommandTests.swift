// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation
import OmniWMIPC
import XCTest

final class IPCSetGapsCommandTests: XCTestCase {
    func testNameMapsToSetGapBottom() {
        XCTAssertEqual(IPCCommandRequest.setGapBottom(points: 25).name, .setGapBottom)
    }

    func testConstructionFromArgumentValues() throws {
        let request = try IPCCommandRequest(name: .setGapBottom, argumentValues: [.double(25)])
        XCTAssertEqual(request, .setGapBottom(points: 25))
    }

    func testConstructionRejectsMissingArgument() {
        XCTAssertThrowsError(try IPCCommandRequest(name: .setGapBottom, argumentValues: []))
    }

    func testJSONRoundTrip() throws {
        let original = IPCCommandRequest.setGapBottom(points: 0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IPCCommandRequest.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testManifestResolvesPublicCommand() throws {
        let descriptors = IPCAutomationManifest.commandDescriptors(matching: ["set-gaps", "--bottom", "25"])
        let descriptor = try XCTUnwrap(descriptors.first { $0.name == .setGapBottom })
        XCTAssertEqual(descriptor.commandWords, ["set-gaps", "--bottom"])
        XCTAssertEqual(descriptor.arguments.map(\.kind), [.points])
        let request = try IPCCommandRequest(name: descriptor.name, argumentValues: [.double(25)])
        XCTAssertEqual(request, .setGapBottom(points: 25))
    }
}
