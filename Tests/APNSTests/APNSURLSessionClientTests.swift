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
import Foundation
import Testing

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
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["apns-request-id": UUID().uuidString]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct APNSURLSessionClientTests {
    @Test func `Send alert success`() async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)

            let response = try await client.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken
            )

            // A 200 must be treated as success even though the body is `{}`.
            #expect(response.apnsID != nil)
        }
    }

    @Test func `Send alert propagates headers to server`() async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)

            _ = try await client.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken
            )

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.deviceToken == TestFixtures.validDeviceToken)
            #expect(sent.pushType == "alert")
            #expect(sent.topic == "com.example.app")
        }
    }

    @Test func `Send alert bad device token throws typed error`() async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)

            let error = try await #require(throws: APNSError.self) {
                try await client.sendAlertNotification(
                    Self.makeAlert(),
                    deviceToken: "not-a-valid-token"
                )
            }
            // The status code must drive the failure (previously the code keyed off
            // whether the body decoded as an error, ignoring the HTTP status).
            #expect(error.responseStatus == 400)
            #expect(error.reason == .badDeviceToken)
        }
    }

    @Test func `Send alert missing topic throws typed error`() async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)

            // Build the request with no topic so the `apns-topic` header is omitted entirely.
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

    @Test func `Send alert propagates all headers`() async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)

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

            _ = try await client.sendAlertNotification(alert, deviceToken: TestFixtures.validDeviceToken)

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.deviceToken == TestFixtures.validDeviceToken)
            #expect(sent.pushType == "alert")
            #expect(sent.topic == "com.example.app")
            #expect(sent.priority == "10")
            #expect(sent.expiration == "0")
            #expect(sent.collapseID == "collapse-123")
            #expect(sent.apnsID == apnsID)
        }
    }

    @Test func `Send alert unregistered carries timestamp`() async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)

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

    @Test func `Injected clock drives token refresh`() async throws {
        try await TestFixtures.withServer { server in
            let clock = TestClock<Duration>()
            let clockedClient = APNSURLSessionClient(
                configuration: .init(
                    environment: .custom(url: "http://127.0.0.1", port: server.port),
                    privateKey: try TestFixtures.signingKey(),
                    keyIdentifier: TestFixtures.keyIdentifier,
                    teamIdentifier: TestFixtures.teamIdentifier,
                    clock: clock
                )
            )

            _ = try await clockedClient.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken
            )

            // Advance past the manager's 55 minute refresh window so a new token must be minted.
            clock.now = clock.now.advanced(by: .init(secondsComponent: 3360, attosecondsComponent: 0))

            _ = try await clockedClient.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken
            )

            let sent = server.getSentNotifications()
            #expect(sent.count == 2)
            let firstAuthorization = try #require(sent[0].authorization)
            let secondAuthorization = try #require(sent[1].authorization)
            #expect(firstAuthorization != secondAuthorization)
        }
    }

    @Test func `Send alert custom session is used`() async throws {
        try await TestFixtures.withServer { server in
            let customSession = URLSession(configuration: .ephemeral)
            let customClient = try TestFixtures.urlSessionClient(for: server, session: customSession)

            let response = try await customClient.sendAlertNotification(
                Self.makeAlert(),
                deviceToken: TestFixtures.validDeviceToken
            )

            #expect(response.apnsID != nil)
        }
    }

    @Test(arguments: [
        (UInt(500), String?.none),
        (UInt(503), "<html>unavailable</html>"),
    ])
    func `Undecodable error body yields typed error with nil reason`(status: UInt, body: String?) async throws {
        try await TestFixtures.withServer { server in
            let client = try TestFixtures.urlSessionClient(for: server)
            server.setResponseOverride(.init(status: status, body: body))

            let error = try await #require(throws: APNSError.self) {
                try await client.sendAlertNotification(Self.makeAlert(), deviceToken: TestFixtures.validDeviceToken)
            }
            #expect(error.responseStatus == Int(status))
            #expect(error.reason == nil)
        }
    }

    @Test func `Send broadcast uses injected session`() async throws {
        try await TestFixtures.withServer { server in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RecordingURLProtocol.self]
            let client = try TestFixtures.urlSessionClient(for: server, session: URLSession(configuration: configuration))

            let request = APNSBroadcastSendRequest(
                message: Self.makeAlert(),
                channelID: "channel",
                bundleID: "com.example.app",
                expiration: .immediately,
                priority: .immediately
            )

            RecordingURLProtocol.reset()
            _ = try await client.sendBroadcast(request)

            let recorded = try #require(RecordingURLProtocol.lastRequest)
            #expect(recorded.url?.path == "/4/broadcasts/apps/com.example.app")
            #expect(recorded.value(forHTTPHeaderField: "user-agent") == "APNS/swift-urlsession")
            #expect(server.getBroadcastSends().count == 0)
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
#endif
