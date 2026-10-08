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

/// Intercepts every request made through a `URLSession` configured with it and answers `200 {}`.
final class RecordingURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var _lastRequest: URLRequest?
    private static let lock = NSLock()

    static var lastRequest: URLRequest? {
        lock.withLock { _lastRequest }
    }

    static func reset() {
        lock.withLock { _lastRequest = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self._lastRequest = request }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["apns-request-id": UUID().uuidString]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

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

    func testSendAlert_propagatesAllHeaders() async throws {
        let apnsID = UUID()
        var alert = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload(),
            apnsID: apnsID
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
        XCTAssertEqual(sent.apnsID, apnsID)
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

    func testInjectedClockDrivesTokenRefresh() async throws {
        let clock = TestClock<Duration>()
        let testServer = server!
        let clockedClient = APNSURLSessionClient(
            configuration: .init(
                environment: .custom(url: "http://127.0.0.1", port: testServer.port),
                privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID",
                clock: clock
            )
        )

        _ = try await clockedClient.sendAlertNotification(
            Self.makeAlert(),
            deviceToken: Self.validDeviceToken
        )

        // Advance past the manager's 55 minute refresh window so a new token must be minted.
        clock.now = clock.now.advanced(by: .init(secondsComponent: 3360, attosecondsComponent: 0))

        _ = try await clockedClient.sendAlertNotification(
            Self.makeAlert(),
            deviceToken: Self.validDeviceToken
        )

        let sent = testServer.getSentNotifications()
        XCTAssertEqual(sent.count, 2)
        let firstAuthorization = try XCTUnwrap(sent[0].authorization)
        let secondAuthorization = try XCTUnwrap(sent[1].authorization)
        XCTAssertNotEqual(firstAuthorization, secondAuthorization)
    }

    func testSendAlert_customSessionIsUsed() async throws {
        let customSession = URLSession(configuration: .ephemeral)
        let customClient = APNSURLSessionClient(
            configuration: .init(
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID"
            ),
            session: customSession
        )

        let response = try await customClient.sendAlertNotification(
            Self.makeAlert(),
            deviceToken: Self.validDeviceToken
        )

        XCTAssertNotNil(response.apnsID)
    }

    func testSendAlert_forced500EmptyBody_yieldsTypedErrorWithNilReason() async throws {
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

    func testSendAlert_forced503NonJSONBody_yieldsTypedErrorWithNilReason() async throws {
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

    func testSendBroadcast_usesInjectedSession() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        let customClient = APNSURLSessionClient(
            configuration: .init(
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID"
            ),
            session: URLSession(configuration: configuration)
        )

        let request = APNSBroadcastSendRequest(
            message: Self.makeAlert(),
            channelID: "channel",
            bundleID: "com.example.app",
            expiration: .immediately,
            priority: .immediately
        )

        RecordingURLProtocol.reset()
        _ = try await customClient.sendBroadcast(request)

        // The mock protocol only intercepts the injected session. If the broadcast path fell back to
        // `URLSession.shared`, the request would reach the real test server and never be recorded here.
        let recorded = try XCTUnwrap(RecordingURLProtocol.lastRequest)
        XCTAssertEqual(recorded.url?.path, "/4/broadcasts/apps/com.example.app")
        XCTAssertEqual(recorded.value(forHTTPHeaderField: "user-agent"), "APNS/swift-urlsession")
        XCTAssertEqual(server.getBroadcastSends().count, 0)
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
