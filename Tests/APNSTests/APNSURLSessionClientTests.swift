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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import APNSCore
import APNSTestServer
@testable import APNSURLSession
import Crypto
import XCTest

final class APNSURLSessionClientTests: XCTestCase {
    var server: APNSTestServer!
    var client: APNSURLSessionClient!

    override func setUp() async throws {
        try await super.setUp()

        server = APNSTestServer()
        try await server.start(port: 0)

        client = APNSURLSessionClient(
            configuration: .init(
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID"
            )
        )
    }

    override func tearDown() async throws {
        try await server?.shutdown()
        server = nil
        client = nil
        try await super.tearDown()
    }

    func testSendAlert_success() async throws {
        let response = try await client.sendAlertNotification(
            Self.makeAlert(),
            deviceToken: Self.validDeviceToken
        )

        // A 200 must be treated as success even though the body is `{}`.
        XCTAssertNotNil(response.apnsID)
    }

    func testSendAlert_propagatesHeadersToServer() async throws {
        _ = try await client.sendAlertNotification(
            Self.makeAlert(),
            deviceToken: Self.validDeviceToken
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.deviceToken, Self.validDeviceToken)
        XCTAssertEqual(sent.pushType, "alert")
        XCTAssertEqual(sent.topic, "com.example.app")
    }

    func testSendAlert_badDeviceTokenThrowsTypedError() async throws {
        do {
            _ = try await client.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: "not-a-valid-token"
            )
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            // The status code must drive the failure (previously the code keyed off
            // whether the body decoded as an error, ignoring the HTTP status).
            XCTAssertEqual(error.responseStatus, 400)
            XCTAssertEqual(error.reason, .badDeviceToken)
        }
    }

    func testSendAlert_missingTopicThrowsTypedError() async throws {
        // Build the request with no topic so the `apns-topic` header is omitted entirely.
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
#endif
