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

/// Exercises the NIO-based ``APNSClient``'s error-handling path against forced server responses,
/// via ``APNSTestServer/setResponseOverride(_:)``. These pin the behaviour that an undecodable
/// error body (empty, non-JSON, or oversized) must still surface as a typed `APNSError` with
/// `reason: nil`, rather than a raw `DecodingError`/`NIOTooManyBytesError`.
final class APNSClientErrorPathTests: XCTestCase {
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

    func testForced500_emptyBody_yieldsTypedErrorWithNilReason() async throws {
        server.setResponseOverride(.init(status: 500))

        do {
            _ = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: Self.validDeviceToken)
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 500)
            XCTAssertNil(error.reason)
        } catch {
            XCTFail("Expected an APNSError, got \(type(of: error)): \(error)")
        }
    }

    func testForced503_nonJSONBody_yieldsTypedErrorWithNilReason() async throws {
        server.setResponseOverride(.init(status: 503, body: "<html>unavailable</html>"))

        do {
            _ = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: Self.validDeviceToken)
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 503)
            XCTAssertNil(error.reason)
        } catch {
            XCTFail("Expected an APNSError, got \(type(of: error)): \(error)")
        }
    }

    func testForced429_validBody_yieldsTooManyRequestsReason() async throws {
        server.setResponseOverride(.init(status: 429, body: #"{"reason":"TooManyRequests"}"#))

        do {
            _ = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: Self.validDeviceToken)
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 429)
            XCTAssertEqual(error.reason, .tooManyRequests)
        }
    }

    func testForced400_oversizedBody_yieldsTypedErrorWithNilReason() async throws {
        // Larger than the client's 1024-byte `collect(upTo:)` limit on the error path, pinning
        // the `NIOTooManyBytesError` failure mode.
        let garbage = String(repeating: "x", count: 2048)
        server.setResponseOverride(.init(status: 400, body: garbage))

        do {
            _ = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: Self.validDeviceToken)
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 400)
            XCTAssertNil(error.reason)
        } catch {
            XCTFail("Expected an APNSError, got \(type(of: error)): \(error)")
        }
    }

    func testForced400_channelNotRegistered_throughRealClient() async throws {
        server.setResponseOverride(.init(status: 400, body: #"{"reason":"ChannelNotRegistered"}"#))

        do {
            _ = try await client.sendAlertNotification(Self.makeAlert(), deviceToken: Self.validDeviceToken)
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 400)
            XCTAssertEqual(error.reason, .channelNotRegistered)
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
