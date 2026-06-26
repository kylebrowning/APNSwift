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
import Crypto
import NIOPosix
import XCTest

/// Exercises the NIO-based ``APNSClient`` send path end-to-end against ``APNSTestServer``.
final class APNSClientSendTests: XCTestCase {
    var server: APNSTestServer!
    var client: APNSClient<JSONDecoder, JSONEncoder>!

    override func setUp() async throws {
        try await super.setUp()

        server = APNSTestServer()
        try await server.start(port: 0)

        client = APNSClient(
            configuration: .init(
                authenticationMethod: .jwt(
                    privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                    keyIdentifier: "MY_KEY_ID",
                    teamIdentifier: "MY_TEAM_ID"
                ),
                environment: .custom(url: "http://127.0.0.1", port: server.port)
            ),
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder()
        )
    }

    override func tearDown() async throws {
        try await client?.shutdown()
        try await server?.shutdown()
        client = nil
        server = nil
        try await super.tearDown()
    }

    func testSendAlert_success() async throws {
        let response = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: Self.validDeviceToken)

        XCTAssertNotNil(response.apnsID)
        XCTAssertEqual(server.getSentNotifications().count, 1)
    }

    func testSendAlert_propagatesAllHeaders() async throws {
        var alert = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )
        alert.collapseID = "collapse-123"
        _ = try await client.sendAlertNotification(alert, deviceToken: Self.validDeviceToken)

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.deviceToken, Self.validDeviceToken)
        XCTAssertEqual(sent.pushType, "alert")
        XCTAssertEqual(sent.topic, "com.example.app")
        XCTAssertEqual(sent.priority, "10")
        XCTAssertEqual(sent.expiration, "0")
        XCTAssertEqual(sent.collapseID, "collapse-123")
    }

    func testSendAlert_badDeviceTokenThrowsTypedError() async throws {
        do {
            _ = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: "not-valid")
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 400)
            XCTAssertEqual(error.reason, .badDeviceToken)
        }
    }

    func testSendAlert_missingTopicThrowsTypedError() async throws {
        let request = APNSRequest(
            message: Self.makeAlert(),
            deviceToken: Self.validDeviceToken,
            pushType: .alert,
            expiration: nil,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )
        do {
            _ = try await client.send(request)
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 400)
            XCTAssertEqual(error.reason, .missingTopic)
        }
    }

    func testSendAlert_unregisteredCarriesTimestamp() async throws {
        do {
            _ = try await client.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: APNSTestServer.unregisteredDeviceToken
            )
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 410)
            XCTAssertEqual(error.reason, .unregistered)
            let timestamp = try XCTUnwrap(error.timestamp)
            XCTAssertEqual(
                timestamp.timeIntervalSince1970,
                Double(APNSTestServer.unregisteredTimestampMilliseconds) / 1000,
                accuracy: 0.001
            )
        }
    }

    // MARK: - Helpers

    private static let validDeviceToken = String(repeating: "a", count: 64)

    private static func makeAlert() -> APNSAlertNotification<EmptyPayload> {
        APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )
    }

    private static let jwtPrivateKey = """
    -----BEGIN PRIVATE KEY-----
    MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg2sD+kukkA8GZUpmm
    jRa4fJ9Xa/JnIG4Hpi7tNO66+OGgCgYIKoZIzj0DAQehRANCAATZp0yt0btpR9kf
    ntp4oUUzTV0+eTELXxJxFvhnqmgwGAm1iVW132XLrdRG/ntlbQ1yzUuJkHtYBNve
    y+77Vzsd
    -----END PRIVATE KEY-----
    """
}
