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
import Foundation
import NIOPosix
import Testing

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import APNSURLSession
#endif

/// Exercises `POST /4/broadcasts/apps/{bundleID}` end-to-end against `APNSTestServer`.
///
/// Channel CRUD goes through ``APNSBroadcastClient`` (the `/1/apps/...` management host), while
/// broadcast *send* goes through the regular device-push ``APNSClient`` (the `/4/broadcasts/apps/...`
/// path lives on the same host as `/3/device/...`). Both clients are pointed at the same mock server.
struct APNSBroadcastSendTests {
    @Test func `Send broadcast live activity update success`() async throws {
        try await Self.withClients { server, broadcastClient, client in
            let channelID = try await Self.createChannel(using: broadcastClient)

            let response = try await client.sendBroadcastLiveActivityNotification(
                Self.makeUpdate(),
                channelID: channelID,
                bundleID: Self.bundleID
            )

            #expect(response.apnsRequestID != nil)
            #expect(response.apnsUniqueID != nil)

            let sends = server.getBroadcastSends()
            #expect(sends.count == 1)

            let sent = try #require(sends.first)
            #expect(sent.bundleID == Self.bundleID)
            #expect(sent.channelID == channelID)
            #expect(sent.pushType == "liveactivity")

            let payload = try sent.decodedPayload(as: BroadcastPayload.self)
            #expect(payload.aps.event == "update")
        }
    }

    @Test func `Send broadcast request ID echo`() async throws {
        try await Self.withClients { server, broadcastClient, client in
            let channelID = try await Self.createChannel(using: broadcastClient)
            let requestID = UUID()

            let response = try await client.sendBroadcastLiveActivityNotification(
                Self.makeUpdate(),
                channelID: channelID,
                bundleID: Self.bundleID,
                apnsRequestID: requestID
            )

            #expect(response.apnsRequestID == requestID)

            let sent = try #require(server.getBroadcastSends().first)
            #expect(sent.receivedRequestID == requestID.uuidString.lowercased())
        }
    }

    @Test func `Send broadcast channel not registered`() async throws {
        try await Self.withClients { _, _, client in
            let error = try await #require(throws: APNSError.self) {
                try await client.sendBroadcastLiveActivityNotification(
                    Self.makeUpdate(),
                    channelID: UUID().uuidString,
                    bundleID: Self.bundleID
                )
            }
            // A parallel PR may add a typed `.channelNotRegistered` reason; keep this robust
            // against that by only asserting the status code here.
            #expect(error.responseStatus == 400)
        }
    }

    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    @Test func `Send broadcast live activity update URLSession client success`() async throws {
        try await Self.withClients { server, broadcastClient, _ in
            let channelID = try await Self.createChannel(using: broadcastClient)

            let urlSessionClient = try TestFixtures.urlSessionClient(for: server)

            let request = APNSBroadcastSendRequest(
                message: Self.makeUpdate(),
                channelID: channelID,
                bundleID: Self.bundleID,
                expiration: .immediately,
                priority: .immediately
            )

            let response = try await urlSessionClient.sendBroadcast(request)

            #expect(response.apnsRequestID != nil)
            #expect(response.apnsUniqueID != nil)

            let sends = server.getBroadcastSends()
            #expect(sends.count == 1)
            #expect(sends.first?.channelID == channelID)
        }
    }
    #endif

    @Test func `Send broadcast payload too large`() async throws {
        try await Self.withClients { _, broadcastClient, client in
            let channelID = try await Self.createChannel(using: broadcastClient)

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

            let error = try await #require(throws: APNSError.self) {
                try await client.sendBroadcastLiveActivityNotification(
                    notification,
                    channelID: channelID,
                    bundleID: Self.bundleID
                )
            }
            #expect(error.responseStatus == 413)
        }
    }

    @Test(arguments: [
        (UInt(503), "<html>unavailable</html>"),
        (UInt(500), String?.none),
    ])
    func `Send broadcast undecodable error body yields typed error with nil reason`(status: UInt, body: String?) async throws {
        try await Self.withClients { server, broadcastClient, client in
            let channelID = try await Self.createChannel(using: broadcastClient)
            server.setResponseOverride(.init(status: status, body: body))

            let error = try await #require(throws: APNSError.self) {
                try await client.sendBroadcastLiveActivityNotification(
                    Self.makeUpdate(),
                    channelID: channelID,
                    bundleID: Self.bundleID
                )
            }
            #expect(error.responseStatus == Int(status))
            #expect(error.reason == nil)
        }
    }

    // MARK: - Helpers

    private static let bundleID = "com.example.testapp"

    private static func withClients<T>(
        _ body: (
            APNSTestServer,
            APNSBroadcastClient<JSONDecoder, JSONEncoder>,
            APNSClient<JSONDecoder, JSONEncoder>
        ) async throws -> T
    ) async throws -> T {
        try await TestFixtures.withServer { server in
            let broadcastClient = APNSBroadcastClient(
                authenticationMethod: try TestFixtures.jwtAuthentication(),
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                bundleID: Self.bundleID,
                eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder()
            )
            let client = APNSClient(
                configuration: .init(
                    authenticationMethod: try TestFixtures.jwtAuthentication(),
                    environment: .custom(url: "http://127.0.0.1", port: server.port)
                ),
                eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder()
            )
            do {
                let result = try await body(server, broadcastClient, client)
                try await broadcastClient.shutdown()
                try await client.shutdown()
                return result
            } catch {
                try? await broadcastClient.shutdown()
                try? await client.shutdown()
                throw error
            }
        }
    }

    private static func createChannel(
        using broadcastClient: APNSBroadcastClient<JSONDecoder, JSONEncoder>
    ) async throws -> String {
        let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let response = try await broadcastClient.create(channel: channel, apnsRequestID: nil)
        return try #require(response.channelID)
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
}
