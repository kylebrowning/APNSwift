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

@testable import APNSCore
import APNS
import Foundation
import Testing

struct APNSBroadcastClientTests {
    @Test func `Create channel`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
            let response = try await client.create(channel: channel, apnsRequestID: nil)

            #expect(response.apnsRequestID != nil)
            #expect(response.channelID != nil)
        }
    }

    @Test func `Create channel no message stored`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            let channel = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
            let response = try await client.create(channel: channel, apnsRequestID: nil)

            #expect(response.apnsRequestID != nil)
            #expect(response.channelID != nil)
        }
    }

    @Test func `Read channel`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            // First, create a channel
            let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
            let createResponse = try await client.create(channel: channel, apnsRequestID: nil)
            let channelID = try #require(createResponse.channelID)

            // Now read it back
            let readResponse = try await client.read(channelID: channelID, apnsRequestID: nil)

            #expect(readResponse.apnsRequestID != nil)
            #expect(readResponse.channelID == channelID)
            #expect(readResponse.body?.messageStoragePolicy == .mostRecentMessageStored)
            #expect(readResponse.body?.pushType == "LiveActivity")
        }
    }

    @Test func `Read channel not found`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            let error = try await #require(throws: APNSError.self) {
                try await client.read(channelID: "non-existent-channel", apnsRequestID: nil)
            }
            #expect(error.responseStatus == 400)
            #expect(error.reason == .channelNotRegistered)
        }
    }

    @Test func `Delete channel`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            // First, create a channel
            let channel = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
            let createResponse = try await client.create(channel: channel, apnsRequestID: nil)
            let channelID = try #require(createResponse.channelID)

            // Delete it
            let deleteResponse = try await client.delete(channelID: channelID, apnsRequestID: nil)
            #expect(deleteResponse.apnsRequestID != nil)

            // Verify it's gone
            let error = try await #require(throws: APNSError.self) {
                try await client.read(channelID: channelID, apnsRequestID: nil)
            }
            #expect(error.responseStatus == 400)
            #expect(error.reason == .channelNotRegistered)
        }
    }

    @Test func `Delete channel not found`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            let error = try await #require(throws: APNSError.self) {
                try await client.delete(channelID: "non-existent-channel", apnsRequestID: nil)
            }
            #expect(error.responseStatus == 400)
            #expect(error.reason == .channelNotRegistered)
        }
    }

    @Test func `List all channels`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            // Create a few channels
            let channel1 = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
            let channel2 = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
            let channel3 = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)

            let response1 = try await client.create(channel: channel1, apnsRequestID: nil)
            let response2 = try await client.create(channel: channel2, apnsRequestID: nil)
            let response3 = try await client.create(channel: channel3, apnsRequestID: nil)

            let channelID1 = try #require(response1.channelID)
            let channelID2 = try #require(response2.channelID)
            let channelID3 = try #require(response3.channelID)

            // List all channels
            let listResponse = try await client.readAllChannelIDs(apnsRequestID: nil)

            #expect(listResponse.apnsRequestID != nil)
            let channels = try #require(listResponse.body?.channels)
            #expect(channels.count == 3)
            #expect(channels.contains(channelID1))
            #expect(channels.contains(channelID2))
            #expect(channels.contains(channelID3))
        }
    }

    @Test func `List all channels empty`() async throws {
        try await TestFixtures.withBroadcastClient { _, client in
            let listResponse = try await client.readAllChannelIDs(apnsRequestID: nil)

            #expect(listResponse.apnsRequestID != nil)
            let channels = try #require(listResponse.body?.channels)
            #expect(channels.count == 0)
        }
    }

    // MARK: - Operation path contract

    @Test func `Operation paths`() {
        // Individual channel operations target `/channels`...
        #expect(APNSBroadcastRequest<EmptyPayload>(operation: .create).operation.path == "/channels")
        #expect(APNSBroadcastRequest<EmptyPayload>(operation: .read(channelID: "x")).operation.path == "/channels")
        #expect(APNSBroadcastRequest<EmptyPayload>(operation: .delete(channelID: "x")).operation.path == "/channels")
        // ...while "read all channels" lives on Apple's distinct `/all-channels` endpoint.
        #expect(APNSBroadcastRequest<EmptyPayload>(operation: .listAll).operation.path == "/all-channels")
    }

    @Test func `Request ID`() async throws {
        try await TestFixtures.withBroadcastClient { server, client in
            let requestID = UUID()
            let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
            let response = try await client.create(channel: channel, apnsRequestID: requestID)

            // The server echoes back the `apns-request-id` header the client sent.
            let requests = server.getBroadcastRequests()
            let createRequest = try #require(requests.first { $0.method == "POST" })
            #expect(createRequest.apnsRequestID == requestID.uuidString.lowercased())

            #expect(response.apnsRequestID == requestID)
        }
    }
}
