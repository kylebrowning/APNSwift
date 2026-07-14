//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2025 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import APNSCore
import APNS
import APNSTestServer
import Crypto
import NIOPosix
import XCTest

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import APNSURLSession
#endif

/// Exercises `POST /4/broadcasts/apps/{bundleID}` end-to-end against `APNSTestServer`.
///
/// Channel CRUD goes through ``APNSBroadcastClient`` (the `/1/apps/...` management host), while
/// broadcast *send* goes through the regular device-push ``APNSClient`` (the `/4/broadcasts/apps/...`
/// path lives on the same host as `/3/device/...`). Both clients are pointed at the same mock server.
final class APNSBroadcastSendTests: XCTestCase {
    var server: APNSTestServer!
    var broadcastClient: APNSBroadcastClient<JSONDecoder, JSONEncoder>!
    var client: APNSClient<JSONDecoder, JSONEncoder>!

    override func setUp() async throws {
        try await super.setUp()

        server = APNSTestServer()
        try await server.start(port: 0)

        let serverPort = server.port

        broadcastClient = APNSBroadcastClient(
            authenticationMethod: .jwt(
                privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID"
            ),
            environment: .custom(url: "http://127.0.0.1", port: serverPort),
            bundleID: Self.bundleID,
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder()
        )

        client = APNSClient(
            configuration: .init(
                authenticationMethod: .jwt(
                    privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                    keyIdentifier: "MY_KEY_ID",
                    teamIdentifier: "MY_TEAM_ID"
                ),
                environment: .custom(url: "http://127.0.0.1", port: serverPort)
            ),
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder()
        )
    }

    override func tearDown() async throws {
        try await broadcastClient?.shutdown()
        try await client?.shutdown()
        try await server?.shutdown()
        broadcastClient = nil
        client = nil
        server = nil
        try await super.tearDown()
    }

    func testSendBroadcastLiveActivityUpdate_success() async throws {
        let channelID = try await createChannel()

        let response = try await client.sendBroadcastLiveActivityNotification(
            Self.makeUpdate(),
            channelID: channelID,
            bundleID: Self.bundleID
        )

        XCTAssertNotNil(response.apnsRequestID)
        XCTAssertNotNil(response.apnsUniqueID)

        let sends = server.getBroadcastSends()
        XCTAssertEqual(sends.count, 1)

        let sent = try XCTUnwrap(sends.first)
        XCTAssertEqual(sent.bundleID, Self.bundleID)
        XCTAssertEqual(sent.channelID, channelID)
        XCTAssertEqual(sent.pushType, "liveactivity")

        let payload = try sent.decodedPayload(as: BroadcastPayload.self)
        XCTAssertEqual(payload.aps.event, "update")
    }

    func testSendBroadcast_requestIDEcho() async throws {
        let channelID = try await createChannel()
        let requestID = UUID()

        let response = try await client.sendBroadcastLiveActivityNotification(
            Self.makeUpdate(),
            channelID: channelID,
            bundleID: Self.bundleID,
            apnsRequestID: requestID
        )

        XCTAssertEqual(response.apnsRequestID, requestID)

        let sent = try XCTUnwrap(server.getBroadcastSends().first)
        XCTAssertEqual(sent.receivedRequestID, requestID.uuidString.lowercased())
    }

    func testSendBroadcast_channelNotRegistered() async throws {
        do {
            _ = try await client.sendBroadcastLiveActivityNotification(
                Self.makeUpdate(),
                channelID: UUID().uuidString,
                bundleID: Self.bundleID
            )
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            // A parallel PR may add a typed `.channelNotRegistered` reason; keep this robust
            // against that by only asserting the status code here.
            XCTAssertEqual(error.responseStatus, 400)
        }
    }

    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    func testSendBroadcastLiveActivityUpdate_urlSessionClient_success() async throws {
        let channelID = try await createChannel()

        let urlSessionClient = APNSURLSessionClient(
            configuration: .init(
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                privateKey: try P256.Signing.PrivateKey(pemRepresentation: Self.jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID"
            )
        )

        let request = APNSBroadcastSendRequest(
            message: Self.makeUpdate(),
            channelID: channelID,
            bundleID: Self.bundleID,
            expiration: .immediately,
            priority: .immediately
        )

        let response = try await urlSessionClient.sendBroadcast(request)

        XCTAssertNotNil(response.apnsRequestID)
        XCTAssertNotNil(response.apnsUniqueID)

        let sends = server.getBroadcastSends()
        XCTAssertEqual(sends.count, 1)
        XCTAssertEqual(sends.first?.channelID, channelID)
    }
    #endif

    func testSendBroadcast_payloadTooLarge() async throws {
        let channelID = try await createChannel()

        // Comfortably over the 5,120-byte broadcast payload limit.
        let oversizedState = LargeContentState(text: String(repeating: "x", count: 6000))
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: Self.bundleID,
            contentState: oversizedState,
            event: .update,
            timestamp: 0
        )

        do {
            _ = try await client.sendBroadcastLiveActivityNotification(
                notification,
                channelID: channelID,
                bundleID: Self.bundleID
            )
            XCTFail("Expected an APNSError to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 413)
        }
    }

    // MARK: - Helpers

    private static let bundleID = "com.example.testapp"

    private func createChannel() async throws -> String {
        let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let response = try await broadcastClient.create(channel: channel, apnsRequestID: nil)
        return try XCTUnwrap(response.channelID)
    }

    private static func makeUpdate() -> APNSLiveActivityNotification<ExampleContentState> {
        APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: Self.bundleID,
            contentState: ExampleContentState(message: "hello"),
            event: .update,
            timestamp: 0
        )
    }

    private struct ExampleContentState: Codable, Sendable {
        let message: String
    }

    private struct LargeContentState: Codable, Sendable {
        let text: String
    }

    private struct BroadcastPayload: Decodable {
        struct APS: Decodable {
            let event: String
        }
        let aps: APS
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
