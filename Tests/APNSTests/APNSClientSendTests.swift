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
import APNS
import APNSTestServer
import Foundation
import Testing

/// Exercises the NIO-based ``APNSClient`` send path end-to-end against ``APNSTestServer``.
struct APNSClientSendTests {

    @Test func `Send alert succeeds`() async throws {
        try await TestFixtures.withClient { server, client in
            let response = try await client.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken
            )

            #expect(response.apnsID != nil)
            // The mock server simulates the development environment, which always returns apns-unique-id.
            #expect(response.apnsUniqueID != nil)
            #expect(server.getSentNotifications().count == 1)
        }
    }

    @Test func `Send alert propagates all headers`() async throws {
        try await TestFixtures.withClient { server, client in
            var alert = APNSAlertNotification(
                alert: .init(title: .raw("title")),
                expiration: .immediately,
                priority: .immediately,
                topic: "com.example.app",
                payload: EmptyPayload()
            )
            alert.collapseID = "collapse-123"
            _ = try await client.sendAlertNotification(alert, deviceToken: TestFixtures.validDeviceToken)

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.deviceToken == TestFixtures.validDeviceToken)
            #expect(sent.pushType == "alert")
            #expect(sent.topic == "com.example.app")
            #expect(sent.priority == "10")
            #expect(sent.expiration == "0")
            #expect(sent.collapseID == "collapse-123")
        }
    }

    @Test func `Send alert with bad device token throws typed error`() async throws {
        try await TestFixtures.withClient { _, client in
            let error = try await #require(throws: APNSError.self) {
                try await client.sendAlertNotification(Self.makeAlert(), deviceToken: "not-valid")
            }
            #expect(error.responseStatus == 400)
            #expect(error.reason == .badDeviceToken)
        }
    }

    @Test func `Send alert with missing topic throws typed error`() async throws {
        try await TestFixtures.withClient { _, client in
            let request = APNSRequest(
                message: Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken,
                pushType: .alert,
                expiration: nil,
                priority: nil,
                apnsID: nil,
                topic: nil,
                collapseID: nil
            )
            let error = try await #require(throws: APNSError.self) {
                try await client.send(request)
            }
            #expect(error.responseStatus == 400)
            #expect(error.reason == .missingTopic)
        }
    }

    @Test func `Send alert to unregistered device carries timestamp`() async throws {
        try await TestFixtures.withClient { _, client in
            let error = try await #require(throws: APNSError.self) {
                try await client.sendAlertNotification(
                    Self.makeAlert(),
                    deviceToken: APNSTestServer.unregisteredDeviceToken
                )
            }
            #expect(error.responseStatus == 410)
            #expect(error.reason == .unregistered)
            let timestamp = try #require(error.timestamp)
            let expected = Double(APNSTestServer.unregisteredTimestampMilliseconds) / 1000
            #expect(abs(timestamp.timeIntervalSince1970 - expected) <= 0.001)
        }
    }

    // MARK: - Helpers

    private static func makeAlert() -> APNSAlertNotification<EmptyPayload> {
        APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )
    }
}
