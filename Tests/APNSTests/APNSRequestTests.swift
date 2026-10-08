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
import Foundation
import Testing

private struct TestMessage: APNSMessage {}

/// Direct coverage of ``APNSCore.APNSRequest.headers``, which is the URLSession client's
/// entire header contract.
struct APNSRequestTests {
    @Test func `Full request emits all headers`() throws {
        let apnsID = UUID()
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            pushType: .alert,
            expiration: .timeIntervalSince1970InSeconds(1_234_567_890),
            priority: .immediately,
            apnsID: apnsID,
            topic: "com.example.app",
            collapseID: "collapse-123"
        )

        let headers = request.headers

        #expect(headers["apns-id"] == apnsID.uuidString.lowercased())
        #expect(headers["apns-expiration"] == "1234567890")
        #expect(headers["apns-priority"] == "10")
        #expect(headers["apns-topic"] == "com.example.app")
        #expect(headers["apns-collapse-id"] == "collapse-123")
        #expect(headers["apns-push-type"] == "alert")
    }

    @Test func `apns-id header is lowercased`() throws {
        // UUID() can produce uppercase hex; the header value must always be lowercased.
        let apnsID = try #require(UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890"))
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: nil,
            priority: nil,
            apnsID: apnsID,
            topic: nil,
            collapseID: nil
        )

        #expect(request.headers["apns-id"] == "abcdef12-3456-7890-abcd-ef1234567890")
    }

    @Test func `Minimal request omits optional headers`() throws {
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .background,
            expiration: nil,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        let headers = request.headers

        #expect(headers["apns-push-type"] == "background")
        #expect(headers["apns-id"] == nil)
        #expect(headers["apns-expiration"] == nil)
        #expect(headers["apns-priority"] == nil)
        #expect(headers["apns-topic"] == nil)
        #expect(headers["apns-collapse-id"] == nil)
    }

    @Test func `Expiration immediately is zero`() throws {
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: .immediately,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        #expect(request.headers["apns-expiration"] == "0")
    }

    @Test func `Expiration none omits header`() throws {
        // `APNSNotificationExpiration.none` (as opposed to a `nil` `APNSRequest.expiration`)
        // must also omit the header.
        let noneExpiration: APNSNotificationExpiration? = APNSNotificationExpiration.none
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: noneExpiration,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        #expect(request.headers["apns-expiration"] == nil)
    }

    @Test func `Setters round trip every property`() {
        var request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: nil,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        let apnsID = UUID()
        request.message = TestMessage()
        request.deviceToken = "other-token"
        request.pushType = .background
        request.expiration = .immediately
        request.priority = .consideringDevicePower
        request.apnsID = apnsID
        request.topic = "com.example.app"
        request.collapseID = "collapse"

        #expect(request.deviceToken == "other-token")
        #expect(request.pushType == .background)
        #expect(request.expiration == .immediately)
        #expect(request.priority == .consideringDevicePower)
        #expect(request.apnsID == apnsID)
        #expect(request.topic == "com.example.app")
        #expect(request.collapseID == "collapse")
    }

    @Test func `Mutating a copy does not affect the original`() {
        let original = APNSRequest(
            message: TestMessage(),
            deviceToken: "original-token",
            pushType: .alert,
            expiration: .immediately,
            priority: .immediately,
            apnsID: nil,
            topic: "com.example.app",
            collapseID: nil
        )

        var copy = original
        copy.deviceToken = "copy-token"
        copy.pushType = .voip
        copy.expiration = .none
        copy.priority = nil
        copy.apnsID = UUID()
        copy.topic = "com.example.app.voip"
        copy.collapseID = "collapse"

        #expect(original.deviceToken == "original-token")
        #expect(original.pushType == .alert)
        #expect(original.expiration == .immediately)
        #expect(original.priority == .immediately)
        #expect(original.apnsID == nil)
        #expect(original.topic == "com.example.app")
        #expect(original.collapseID == nil)
        #expect(copy.deviceToken == "copy-token")
        #expect(copy.headers["apns-push-type"] == "voip")
        #expect(copy.headers["apns-expiration"] == nil)
    }

    @Test func `Accessory push type header`() {
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .accessory,
            expiration: nil,
            priority: nil,
            apnsID: nil,
            topic: "com.example.app.push-type.accessory",
            collapseID: nil
        )

        #expect(request.headers["apns-push-type"] == "accessory")
        #expect(request.headers["apns-topic"] == "com.example.app.push-type.accessory")
    }

}
