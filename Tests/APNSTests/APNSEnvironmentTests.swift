//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2024 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import APNSCore
import XCTest

final class APNSEnvironmentTests: XCTestCase {
    func testProduction() {
        XCTAssertEqual(APNSEnvironment.production.url, "https://api.push.apple.com")
        XCTAssertEqual(APNSEnvironment.production.port, 443)
        XCTAssertEqual(APNSEnvironment.production.absoluteURL, "https://api.push.apple.com:443/3/device")
    }

    func testDevelopment() {
        XCTAssertEqual(APNSEnvironment.development.url, "https://api.development.push.apple.com")
        XCTAssertEqual(APNSEnvironment.development.port, 443)
        XCTAssertEqual(APNSEnvironment.development.absoluteURL, "https://api.development.push.apple.com:443/3/device")
    }

    @available(*, deprecated, message: "Intentionally exercising the deprecated `.sandbox` alias.")
    func testSandbox_isAliasForDevelopment() {
        // `.sandbox` is deprecated in favor of `.development`, but must remain behaviorally identical.
        let sandbox = APNSEnvironment.sandbox
        XCTAssertEqual(sandbox.url, APNSEnvironment.development.url)
        XCTAssertEqual(sandbox.port, APNSEnvironment.development.port)
        XCTAssertEqual(sandbox.absoluteURL, APNSEnvironment.development.absoluteURL)
    }

    func testCustom_composesURLAndPort() {
        let custom = APNSEnvironment.custom(url: "http://127.0.0.1", port: 8080)
        XCTAssertEqual(custom.url, "http://127.0.0.1")
        XCTAssertEqual(custom.port, 8080)
        XCTAssertEqual(custom.absoluteURL, "http://127.0.0.1:8080/3/device")
    }

    func testCustom_defaultsPortTo443() {
        let custom = APNSEnvironment.custom(url: "https://example.com")
        XCTAssertEqual(custom.port, 443)
        XCTAssertEqual(custom.absoluteURL, "https://example.com:443/3/device")
    }
}

final class APNSBroadcastEnvironmentTests: XCTestCase {
    func testProduction() {
        XCTAssertEqual(APNSBroadcastEnvironment.production.url, "https://api-manage-broadcast.push.apple.com")
        XCTAssertEqual(APNSBroadcastEnvironment.production.port, 2196)
    }

    func testDevelopment() {
        XCTAssertEqual(APNSBroadcastEnvironment.development.url, "https://api-manage-broadcast.sandbox.push.apple.com")
        XCTAssertEqual(APNSBroadcastEnvironment.development.port, 2195)
    }

    func testCustom_composesURLAndPort() {
        let custom = APNSBroadcastEnvironment.custom(url: "http://127.0.0.1", port: 9090)
        XCTAssertEqual(custom.url, "http://127.0.0.1")
        XCTAssertEqual(custom.port, 9090)
    }

    func testCustom_defaultsPortTo443() {
        let custom = APNSBroadcastEnvironment.custom(url: "https://example.com")
        XCTAssertEqual(custom.port, 443)
    }
}
