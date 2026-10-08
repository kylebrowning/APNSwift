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
import Testing

struct APNSEnvironmentTests {
    @Test func production() {
        #expect(APNSEnvironment.production.url == "https://api.push.apple.com")
        #expect(APNSEnvironment.production.port == 443)
        #expect(APNSEnvironment.production.absoluteURL == "https://api.push.apple.com:443/3/device")
    }

    @Test func development() {
        #expect(APNSEnvironment.development.url == "https://api.development.push.apple.com")
        #expect(APNSEnvironment.development.port == 443)
        #expect(APNSEnvironment.development.absoluteURL == "https://api.development.push.apple.com:443/3/device")
    }

    @available(*, deprecated, message: "Intentionally exercising the deprecated `.sandbox` alias.")
    @Test func `Sandbox is alias for development`() {
        // `.sandbox` is deprecated in favor of `.development`, but must remain behaviorally identical.
        let sandbox = APNSEnvironment.sandbox
        #expect(sandbox.url == APNSEnvironment.development.url)
        #expect(sandbox.port == APNSEnvironment.development.port)
        #expect(sandbox.absoluteURL == APNSEnvironment.development.absoluteURL)
    }

    @Test func `Custom composes URL and port`() {
        let custom = APNSEnvironment.custom(url: "http://127.0.0.1", port: 8080)
        #expect(custom.url == "http://127.0.0.1")
        #expect(custom.port == 8080)
        #expect(custom.absoluteURL == "http://127.0.0.1:8080/3/device")
    }

    @Test func `Custom defaults port to 443`() {
        let custom = APNSEnvironment.custom(url: "https://example.com")
        #expect(custom.port == 443)
        #expect(custom.absoluteURL == "https://example.com:443/3/device")
    }
}

struct APNSBroadcastEnvironmentTests {
    @Test func production() {
        #expect(APNSBroadcastEnvironment.production.url == "https://api-manage-broadcast.push.apple.com")
        #expect(APNSBroadcastEnvironment.production.port == 2196)
    }

    @Test func development() {
        #expect(APNSBroadcastEnvironment.development.url == "https://api-manage-broadcast.sandbox.push.apple.com")
        #expect(APNSBroadcastEnvironment.development.port == 2195)
    }

    @Test func `Custom composes URL and port`() {
        let custom = APNSBroadcastEnvironment.custom(url: "http://127.0.0.1", port: 9090)
        #expect(custom.url == "http://127.0.0.1")
        #expect(custom.port == 9090)
    }

    @Test func `Custom defaults port to 443`() {
        let custom = APNSBroadcastEnvironment.custom(url: "https://example.com")
        #expect(custom.port == 443)
    }
}
