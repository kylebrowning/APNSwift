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
import NIOPosix
import XCTest

final class APNSClientIntegrationTests: XCTestCase {
    var server: APNSTestServer!
    var client: APNSClient<JSONDecoder, JSONEncoder>!

    override func setUp() async throws {
        try await super.setUp()

        // Start the mock server
        server = APNSTestServer()
        try await server.start(port: 0)

        // Create a client pointing to the mock server
        let serverPort = server.port
        client = APNSClient(
            configuration: .init(
                authenticationMethod: .jwt(
                    privateKey: try! P256.Signing.PrivateKey(pemRepresentation: jwtPrivateKey),
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
        try await client?.shutdown()
        try await server?.shutdown()
        client = nil
        server = nil
        try await super.tearDown()
    }

    // MARK: - Alert Notifications

    func testSendAlertNotification() async throws {
        struct Payload: Encodable {
            let customKey = "customValue"
        }

        let notification = APNSAlertNotification(
            alert: .init(title: .raw("Test Title"), body: .raw("Test Body")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: Payload()
        )

        let response = try await client.sendAlertNotification(
            notification,
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        )

        XCTAssertNotNil(response.apnsID)

        // Verify the server received it
        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)

        let sentNotification = sent[0]
        XCTAssertEqual(sentNotification.deviceToken, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        XCTAssertEqual(sentNotification.pushType, "alert")
        XCTAssertEqual(sentNotification.topic, "com.example.app")
        XCTAssertEqual(sentNotification.priority, "10")

        // Verify payload is valid JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: sentNotification.payload))
    }

    func testSendAlertNotification_withBadge() async throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("Badge Test")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload(),
            badge: 5
        )

        _ = try await client.sendAlertNotification(
            notification,
            deviceToken: "1111111111111111111111111111111111111111111111111111111111111111"
        )

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].deviceToken, "1111111111111111111111111111111111111111111111111111111111111111")
        XCTAssertEqual(sent[0].pushType, "alert")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[0].payload) as? NSDictionary)
        let aps = try XCTUnwrap(json["aps"] as? NSDictionary)
        XCTAssertEqual(aps["badge"] as? Int, 5)
    }

    func testSendAlertNotification_withSound() async throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("Sound Test")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload(),
            sound: .default
        )

        _ = try await client.sendAlertNotification(
            notification,
            deviceToken: "2222222222222222222222222222222222222222222222222222222222222222"
        )

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].deviceToken, "2222222222222222222222222222222222222222222222222222222222222222")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[0].payload) as? NSDictionary)
        let aps = try XCTUnwrap(json["aps"] as? NSDictionary)
        XCTAssertEqual(aps["sound"] as? String, "default")
    }

    // MARK: - Background Notifications

    func testSendBackgroundNotification() async throws {
        struct BackgroundPayload: Encodable {
            let data = "background-data"
        }

        let notification = APNSBackgroundNotification(
            expiration: .immediately,
            topic: "com.example.app",
            payload: BackgroundPayload()
        )

        let response = try await client.sendBackgroundNotification(
            notification,
            deviceToken: "3333333333333333333333333333333333333333333333333333333333333333"
        )

        XCTAssertNotNil(response.apnsID)

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].pushType, "background")
        XCTAssertEqual(sent[0].deviceToken, "3333333333333333333333333333333333333333333333333333333333333333")
        XCTAssertEqual(sent[0].topic, "com.example.app")
    }

    // MARK: - VoIP Notifications

    func testSendVoIPNotification() async throws {
        struct VoIPPayload: Encodable {
            let callID = "call-123"
        }

        let notification = APNSVoIPNotification(
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app.voip",
            payload: VoIPPayload()
        )

        _ = try await client.sendVoIPNotification(
            notification,
            deviceToken: "4444444444444444444444444444444444444444444444444444444444444444"
        )

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].pushType, "voip")
        XCTAssertEqual(sent[0].topic, "com.example.app.voip")
        XCTAssertEqual(sent[0].deviceToken, "4444444444444444444444444444444444444444444444444444444444444444")
    }

    // MARK: - File Provider Notifications

    func testSendFileProviderNotification() async throws {
        let notification = APNSFileProviderNotification(
            expiration: .immediately,
            topic: "com.example.app.pushkit.fileprovider",
            payload: EmptyPayload()
        )

        _ = try await client.sendFileProviderNotification(
            notification,
            deviceToken: "5555555555555555555555555555555555555555555555555555555555555555"
        )

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].pushType, "fileprovider")
    }

    // MARK: - Complication Notifications

    func testSendComplicationNotification() async throws {
        let notification = APNSComplicationNotification(
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app.complication",
            payload: EmptyPayload()
        )

        _ = try await client.sendComplicationNotification(
            notification,
            deviceToken: "6666666666666666666666666666666666666666666666666666666666666666"
        )

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].pushType, "complication")
    }

    // MARK: - Live Activity Notifications

    func testSendLiveActivityNotification() async throws {
        struct ContentState: Codable {
            let value: String
        }

        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "com.example.app",
            contentState: ContentState(value: "update-value"),
            event: .update,
            timestamp: 1_234_567_890
        )

        _ = try await client.sendLiveActivityNotification(
            notification,
            deviceToken: "7777777777777777777777777777777777777777777777777777777777777777"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.pushType, "liveactivity")
        XCTAssertEqual(sent.topic, "com.example.app.push-type.liveactivity")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
        let aps = try XCTUnwrap(json["aps"] as? NSDictionary)
        XCTAssertEqual(aps["event"] as? String, "update")
        XCTAssertNotNil(aps["timestamp"])
        XCTAssertNotNil(aps["content-state"])
    }

    func testSendStartLiveActivityNotification() async throws {
        struct Attributes: Codable {}
        struct ContentState: Codable {
            let value: String
        }

        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "com.example.app",
            contentState: ContentState(value: "start-value"),
            timestamp: 1_234_567_890,
            attributes: Attributes(),
            attributesType: "MyActivityAttributes",
            alert: .init(title: .raw("Live Activity Started"))
        )

        _ = try await client.sendStartLiveActivityNotification(
            notification,
            pushToStartToken: "8888888888888888888888888888888888888888888888888888888888888888"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.pushType, "liveactivity")
        XCTAssertEqual(sent.topic, "com.example.app.push-type.liveactivity")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
        let aps = try XCTUnwrap(json["aps"] as? NSDictionary)
        XCTAssertEqual(aps["event"] as? String, "start")
        XCTAssertEqual(aps["attributes-type"] as? String, "MyActivityAttributes")
    }

    // MARK: - Push To Talk Notifications

    func testSendPushToTalkNotification() async throws {
        struct Payload: Encodable {
            let activeSpeaker = "Alice"
        }

        let notification = APNSPushToTalkNotification(
            appID: "com.example.app",
            payload: Payload()
        )

        _ = try await client.sendPushToTalkNotification(
            notification,
            deviceToken: "9999999999999999999999999999999999999999999999999999999999999999"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.pushType, "pushtotalk")
        XCTAssertEqual(sent.topic, "com.example.app.voip-ptt")
        XCTAssertEqual(sent.deviceToken, "9999999999999999999999999999999999999999999999999999999999999999")
        // payload shape asserted in encode tests (see PR1)
    }

    // MARK: - Widgets Notifications

    func testSendWidgetsNotification() async throws {
        let notification = APNSWidgetsNotification(appID: "com.example.app")

        _ = try await client.sendWidgetsNotification(
            notification: notification,
            deviceToken: "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.pushType, "widgets")
        XCTAssertEqual(sent.topic, "com.example.app.push-type.widgets")

        let expectedJSONString = """
        {"aps":{"content-changed":true}}
        """
        let jsonObject1 = try JSONSerialization.jsonObject(with: sent.payload) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    // MARK: - Location Notifications

    func testSendLocationNotification() async throws {
        let notification = APNSLocationNotification(
            priority: .immediately,
            appID: "com.example.app"
        )

        _ = try await client.sendLocationNotification(
            notification,
            deviceToken: "bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.pushType, "location")
        XCTAssertEqual(sent.topic, "com.example.app.location-query")
        // sendLocationNotification forces expiration to `.none`, so no header should be sent.
        XCTAssertNil(sent.expiration)
    }

    // MARK: - Alert Notification Header Variants

    func testSendAlert_consideringDevicePower() async throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("Power Test")),
            expiration: .immediately,
            priority: .consideringDevicePower,
            topic: "com.example.app",
            payload: EmptyPayload()
        )

        _ = try await client.sendAlertNotification(
            notification,
            deviceToken: "cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertEqual(sent.priority, "5")
    }

    func testSendAlert_noExpirationHeaderWhenNone() async throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("Expiration None Test")),
            expiration: .none,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )

        _ = try await client.sendAlertNotification(
            notification,
            deviceToken: "dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444"
        )

        let sent = try XCTUnwrap(server.getSentNotifications().first)
        XCTAssertNil(sent.expiration)
    }

    // MARK: - Multiple Notifications

    func testSendMultipleNotifications() async throws {
        // Send 3 different notifications
        let alert = APNSAlertNotification(
            alert: .init(title: .raw("Alert")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )

        let background = APNSBackgroundNotification(
            expiration: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )

        struct VoIPPayload: Encodable {}
        let voip = APNSVoIPNotification(
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app.voip",
            payload: VoIPPayload()
        )

        _ = try await client.sendAlertNotification(alert, deviceToken: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        _ = try await client.sendBackgroundNotification(background, deviceToken: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        _ = try await client.sendVoIPNotification(voip, deviceToken: "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent.count, 3)

        XCTAssertEqual(sent[0].deviceToken, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        XCTAssertEqual(sent[0].pushType, "alert")

        XCTAssertEqual(sent[1].deviceToken, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(sent[1].pushType, "background")

        XCTAssertEqual(sent[2].deviceToken, "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
        XCTAssertEqual(sent[2].pushType, "voip")
    }

    // MARK: - Header Validation

    func testAPNSID() async throws {
        let testID = UUID()
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("ID Test")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload(),
            apnsID: testID
        )

        _ = try await client.sendAlertNotification(notification, deviceToken: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent[0].apnsID, testID)
    }

    func testExpiration() async throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("Expiration Test")),
            expiration: .timeIntervalSince1970InSeconds(1234567890),
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )

        _ = try await client.sendAlertNotification(notification, deviceToken: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")

        let sent = server.getSentNotifications()
        XCTAssertEqual(sent[0].expiration, "1234567890")
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
