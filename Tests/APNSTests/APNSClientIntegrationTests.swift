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

struct APNSClientIntegrationTests {

    // MARK: - Alert Notifications

    @Test func `Send alert notification`() async throws {
        struct Payload: Encodable {
            let customKey = "customValue"
        }

        try await TestFixtures.withClient { server, client in
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

            #expect(response.apnsID != nil)

            // Verify the server received it
            let sent = server.getSentNotifications()
            #expect(sent.count == 1)

            let sentNotification = sent[0]
            #expect(sentNotification.deviceToken == "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
            #expect(sentNotification.pushType == "alert")
            #expect(sentNotification.topic == "com.example.app")
            #expect(sentNotification.priority == "10")

            // Verify payload is valid JSON
            #expect((try? JSONSerialization.jsonObject(with: sentNotification.payload)) != nil)
        }
    }

    @Test func `Send alert notification with badge`() async throws {
        try await TestFixtures.withClient { server, client in
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
            #expect(sent.count == 1)
            #expect(sent[0].deviceToken == "1111111111111111111111111111111111111111111111111111111111111111")
            #expect(sent[0].pushType == "alert")

            let json = try #require(JSONSerialization.jsonObject(with: sent[0].payload) as? NSDictionary)
            let aps = try #require(json["aps"] as? NSDictionary)
            #expect(aps["badge"] as? Int == 5)
        }
    }

    @Test func `Send alert notification with sound`() async throws {
        try await TestFixtures.withClient { server, client in
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
            #expect(sent.count == 1)
            #expect(sent[0].deviceToken == "2222222222222222222222222222222222222222222222222222222222222222")

            let json = try #require(JSONSerialization.jsonObject(with: sent[0].payload) as? NSDictionary)
            let aps = try #require(json["aps"] as? NSDictionary)
            #expect(aps["sound"] as? String == "default")
        }
    }

    // MARK: - Background Notifications

    @Test func `Send background notification`() async throws {
        struct BackgroundPayload: Encodable {
            let data = "background-data"
        }

        try await TestFixtures.withClient { server, client in
            let notification = APNSBackgroundNotification(
                expiration: .immediately,
                topic: "com.example.app",
                payload: BackgroundPayload()
            )

            let response = try await client.sendBackgroundNotification(
                notification,
                deviceToken: "3333333333333333333333333333333333333333333333333333333333333333"
            )

            #expect(response.apnsID != nil)

            let sent = server.getSentNotifications()
            #expect(sent.count == 1)
            #expect(sent[0].pushType == "background")
            #expect(sent[0].deviceToken == "3333333333333333333333333333333333333333333333333333333333333333")
            #expect(sent[0].topic == "com.example.app")
        }
    }

    // MARK: - VoIP Notifications

    @Test func `Send VoIP notification`() async throws {
        struct VoIPPayload: Encodable {
            let callID = "call-123"
        }

        try await TestFixtures.withClient { server, client in
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
            #expect(sent.count == 1)
            #expect(sent[0].pushType == "voip")
            #expect(sent[0].topic == "com.example.app.voip")
            #expect(sent[0].deviceToken == "4444444444444444444444444444444444444444444444444444444444444444")
        }
    }

    // MARK: - File Provider Notifications

    @Test func `Send file provider notification`() async throws {
        try await TestFixtures.withClient { server, client in
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
            #expect(sent.count == 1)
            #expect(sent[0].pushType == "fileprovider")
        }
    }

    // MARK: - Complication Notifications

    @Test func `Send complication notification`() async throws {
        try await TestFixtures.withClient { server, client in
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
            #expect(sent.count == 1)
            #expect(sent[0].pushType == "complication")
        }
    }

    // MARK: - Live Activity Notifications

    @Test func `Send live activity notification`() async throws {
        struct ContentState: Codable {
            let value: String
        }

        try await TestFixtures.withClient { server, client in
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

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "liveactivity")
            #expect(sent.topic == "com.example.app.push-type.liveactivity")

            let json = try #require(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
            let aps = try #require(json["aps"] as? NSDictionary)
            #expect(aps["event"] as? String == "update")
            #expect(aps["timestamp"] != nil)
            #expect(aps["content-state"] != nil)
        }
    }

    @Test func `Send start live activity notification`() async throws {
        struct Attributes: Codable {}
        struct ContentState: Codable {
            let value: String
        }

        try await TestFixtures.withClient { server, client in
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

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "liveactivity")
            #expect(sent.topic == "com.example.app.push-type.liveactivity")

            let json = try #require(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
            let aps = try #require(json["aps"] as? NSDictionary)
            #expect(aps["event"] as? String == "start")
            #expect(aps["attributes-type"] as? String == "MyActivityAttributes")
        }
    }

    // MARK: - Push To Talk Notifications

    @Test func `Send push to talk notification`() async throws {
        struct Payload: Encodable {
            let activeSpeaker = "Alice"
        }

        try await TestFixtures.withClient { server, client in
            let notification = APNSPushToTalkNotification(
                appID: "com.example.app",
                payload: Payload()
            )

            _ = try await client.sendPushToTalkNotification(
                notification,
                deviceToken: "9999999999999999999999999999999999999999999999999999999999999999"
            )

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "pushtotalk")
            #expect(sent.topic == "com.example.app.voip-ptt")
            #expect(sent.deviceToken == "9999999999999999999999999999999999999999999999999999999999999999")
            // payload shape asserted in encode tests (see PR1)
        }
    }

    // MARK: - Widgets Notifications

    @Test func `Send widgets notification`() async throws {
        try await TestFixtures.withClient { server, client in
            let notification = APNSWidgetsNotification(appID: "com.example.app")

            _ = try await client.sendWidgetsNotification(
                notification: notification,
                deviceToken: "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"
            )

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "widgets")
            #expect(sent.topic == "com.example.app.push-type.widgets")

            let expectedJSONString = """
            {"aps":{"content-changed":true}}
            """
            let jsonObject1 = try #require(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
            let jsonObject2 = try #require(
                JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary
            )
            #expect(jsonObject1 == jsonObject2)
        }
    }

    // MARK: - Controls Notifications

    @Test func `Send controls notification`() async throws {
        try await TestFixtures.withClient { server, client in
            let notification = APNSControlsNotification(appID: "com.example.app")

            _ = try await client.sendControlsNotification(
                notification,
                deviceToken: "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"
            )

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "controls")
            #expect(sent.topic == "com.example.app.push-type.controls")

            let expectedJSONString = """
            {"aps":{"content-changed":true}}
            """
            let jsonObject1 = try #require(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
            let jsonObject2 = try #require(
                JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary
            )
            #expect(jsonObject1 == jsonObject2)
        }
    }

    // MARK: - Accessory Notifications

    @Test func `Send accessory notification`() async throws {
        try await TestFixtures.withClient { server, client in
            let notification = APNSAccessoryNotification(
                appID: "com.example.app",
                encryptedData: "ZW5jcnlwdGVk",
                sessionIdentifier: "session-1",
                keyID: "a2V5",
                messageIndex: 42
            )

            _ = try await client.sendAccessoryNotification(
                notification,
                deviceToken: "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"
            )

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "accessory")
            #expect(sent.topic == "com.example.app.push-type.accessory")

            let expectedJSONString = """
            {"aps":{"encryptedData":"ZW5jcnlwdGVk","sessionIdentifier":"session-1","keyID":"a2V5","messageIndex":"42"}}
            """
            let jsonObject1 = try #require(JSONSerialization.jsonObject(with: sent.payload) as? NSDictionary)
            let jsonObject2 = try #require(
                JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary
            )
            #expect(jsonObject1 == jsonObject2)
        }
    }

    // MARK: - Location Notifications

    @Test func `Send location notification`() async throws {
        try await TestFixtures.withClient { server, client in
            let notification = APNSLocationNotification(
                priority: .immediately,
                appID: "com.example.app"
            )

            _ = try await client.sendLocationNotification(
                notification,
                deviceToken: "bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222"
            )

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.pushType == "location")
            #expect(sent.topic == "com.example.app.location-query")
            // sendLocationNotification forces expiration to `.none`, so no header should be sent.
            #expect(sent.expiration == nil)
        }
    }

    // MARK: - Alert Notification Header Variants

    @Test func `Send alert considering device power`() async throws {
        try await TestFixtures.withClient { server, client in
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

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.priority == "5")
        }
    }

    @Test func `Send alert omits expiration header when none`() async throws {
        try await TestFixtures.withClient { server, client in
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

            let sent = try #require(server.getSentNotifications().first)
            #expect(sent.expiration == nil)
        }
    }

    // MARK: - Multiple Notifications

    @Test func `Send multiple notifications`() async throws {
        struct VoIPPayload: Encodable {}

        try await TestFixtures.withClient { server, client in
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
            #expect(sent.count == 3)

            #expect(sent[0].deviceToken == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
            #expect(sent[0].pushType == "alert")

            #expect(sent[1].deviceToken == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
            #expect(sent[1].pushType == "background")

            #expect(sent[2].deviceToken == "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
            #expect(sent[2].pushType == "voip")
        }
    }

    // MARK: - Header Validation

    @Test func apnsID() async throws {
        try await TestFixtures.withClient { server, client in
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
            #expect(sent[0].apnsID == testID)
        }
    }

    @Test func expiration() async throws {
        try await TestFixtures.withClient { server, client in
            let notification = APNSAlertNotification(
                alert: .init(title: .raw("Expiration Test")),
                expiration: .timeIntervalSince1970InSeconds(1234567890),
                priority: .immediately,
                topic: "com.example.app",
                payload: EmptyPayload()
            )

            _ = try await client.sendAlertNotification(notification, deviceToken: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")

            let sent = server.getSentNotifications()
            #expect(sent[0].expiration == "1234567890")
        }
    }
}
