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
import APNSTestServer
import Crypto
import XCTest

final class APNSBroadcastClientTests: XCTestCase {
    var server: APNSTestServer!
    var client: APNSBroadcastClient<JSONDecoder, JSONEncoder>!

    override func setUp() async throws {
        try await super.setUp()

        // Start the mock server
        server = APNSTestServer()
        try await server.start(port: 0)

        // Create a client pointing to the mock server
        let serverPort = server.port
        client = APNSBroadcastClient(
            authenticationMethod: .jwt(
                privateKey: try! P256.Signing.PrivateKey(pemRepresentation: jwtPrivateKey),
                keyIdentifier: "MY_KEY_ID",
                teamIdentifier: "MY_TEAM_ID"
            ),
            environment: .custom(url: "http://127.0.0.1", port: serverPort),
            bundleID: "com.example.testapp",
            eventLoopGroupProvider: .createNew,
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder()
        )
    }

    override func tearDown() async throws {
        try await client?.shutdown()
        try await server?.shutdown()
        try await super.tearDown()
    }

    func testCreateChannel() async throws {
        let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let response = try await client.create(channel: channel, apnsRequestID: nil)

        XCTAssertNotNil(response.apnsRequestID)
        XCTAssertNotNil(response.channelID)
    }

    func testCreateChannel_noMessageStored() async throws {
        let channel = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
        let response = try await client.create(channel: channel, apnsRequestID: nil)

        XCTAssertNotNil(response.apnsRequestID)
        XCTAssertNotNil(response.channelID)
    }

    func testReadChannel() async throws {
        // First, create a channel
        let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let createResponse = try await client.create(channel: channel, apnsRequestID: nil)
        let channelID = createResponse.channelID!

        // Now read it back
        let readResponse = try await client.read(channelID: channelID, apnsRequestID: nil)

        XCTAssertNotNil(readResponse.apnsRequestID)
        XCTAssertEqual(readResponse.channelID, channelID)
        XCTAssertEqual(readResponse.body?.messageStoragePolicy, .mostRecentMessageStored)
        XCTAssertEqual(readResponse.body?.pushType, "LiveActivity")
    }

    func testReadChannel_notFound() async throws {
        do {
            _ = try await client.read(channelID: "non-existent-channel", apnsRequestID: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 404)
        }
    }

    func testDeleteChannel() async throws {
        // First, create a channel
        let channel = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
        let createResponse = try await client.create(channel: channel, apnsRequestID: nil)
        let channelID = createResponse.channelID!

        // Delete it
        let deleteResponse = try await client.delete(channelID: channelID, apnsRequestID: nil)
        XCTAssertNotNil(deleteResponse.apnsRequestID)

        // Verify it's gone
        do {
            _ = try await client.read(channelID: channelID, apnsRequestID: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 404)
        }
    }

    func testDeleteChannel_notFound() async throws {
        do {
            _ = try await client.delete(channelID: "non-existent-channel", apnsRequestID: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as APNSError {
            XCTAssertEqual(error.responseStatus, 404)
        }
    }

    func testListAllChannels() async throws {
        // Create a few channels
        let channel1 = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let channel2 = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
        let channel3 = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)

        let response1 = try await client.create(channel: channel1, apnsRequestID: nil)
        let response2 = try await client.create(channel: channel2, apnsRequestID: nil)
        let response3 = try await client.create(channel: channel3, apnsRequestID: nil)

        let channelID1 = response1.channelID!
        let channelID2 = response2.channelID!
        let channelID3 = response3.channelID!

        // List all channels
        let listResponse = try await client.readAllChannelIDs(apnsRequestID: nil)

        XCTAssertNotNil(listResponse.apnsRequestID)
        let channels = try XCTUnwrap(listResponse.body?.channels)
        XCTAssertEqual(channels.count, 3)
        XCTAssertTrue(channels.contains(channelID1))
        XCTAssertTrue(channels.contains(channelID2))
        XCTAssertTrue(channels.contains(channelID3))
    }

    func testListAllChannels_empty() async throws {
        let listResponse = try await client.readAllChannelIDs(apnsRequestID: nil)

        XCTAssertNotNil(listResponse.apnsRequestID)
        let channels = try XCTUnwrap(listResponse.body?.channels)
        XCTAssertEqual(channels.count, 0)
    }

    func testRequestID() async throws {
        let requestID = UUID()
        let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let response = try await client.create(channel: channel, apnsRequestID: requestID)

        // The server returns its own request ID, but we verify the client can handle custom IDs
        XCTAssertNotNil(response.apnsRequestID)
    }

    // MARK: - Helper

    private let jwtPrivateKey = """
    -----BEGIN PRIVATE KEY-----
    MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg2sD+kukkA8GZUpmm
    jRa4fJ9Xa/JnIG4Hpi7tNO66+OGgCgYIKoZIzj0DAQehRANCAATZp0yt0btpR9kf
    ntp4oUUzTV0+eTELXxJxFvhnqmgwGAm1iVW132XLrdRG/ntlbQ1yzUuJkHtYBNve
    y+77Vzsd
    -----END PRIVATE KEY-----
    """
}
