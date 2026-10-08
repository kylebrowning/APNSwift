//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2022 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import APNSCore
import XCTest

final class APNSLiveActivityNotificationTests: XCTestCase {

    struct Attributes: Encodable {
        let name: String = "Test Attribute"
    }

    struct State: Encodable, Hashable {
        let string: String = "Test"
        let number: Int = 123
    }

    func testUpdateSetters_areReflectedInEncodedAPS() throws {
        var notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .update,
            timestamp: 0
        )

        notification.timestamp = 1_672_680_658
        notification.event = .end
        notification.contentState = State()
        notification.dismissalDate = .timeIntervalSince1970InSeconds(1_672_690_000)
        notification.staleDate = 1_672_680_800
        notification.alert = .init(title: .raw("Hi"))
        notification.relevanceScore = 0.75

        XCTAssertEqual(notification.timestamp, 1_672_680_658)
        XCTAssertEqual(notification.event, .end)
        XCTAssertEqual(notification.contentState, State())
        XCTAssertEqual(notification.dismissalDate, .timeIntervalSince1970InSeconds(1_672_690_000))
        XCTAssertEqual(notification.staleDate, 1_672_680_800)
        XCTAssertEqual(notification.relevanceScore, 0.75)
        XCTAssertEqual(notification.topic, "test.app.id.push-type.liveactivity")

        let data = try JSONEncoder().encode(notification)
        let expectedJSONString = """
            {"aps":{"event":"end","content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "dismissal-date":1672690000,"stale-date":1672680800,"alert":{"title":"Hi"},"relevance-score":0.75}}
            """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testStartSetters_areReflectedInEncodedAPS() throws {
        var notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 0,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(title: .raw("Hi"))
        )

        notification.timestamp = 1_672_680_658
        notification.alert = .init(title: .raw("Changed"), body: .raw("Body"))
        notification.contentState = State()
        notification.relevanceScore = 0.25

        XCTAssertEqual(notification.timestamp, 1_672_680_658)
        XCTAssertEqual(notification.contentState, State())
        XCTAssertEqual(notification.relevanceScore, 0.25)
        XCTAssertEqual(notification.topic, "test.app.id.push-type.liveactivity")

        let data = try JSONEncoder().encode(notification)
        let expectedJSONString = """
            {"aps":{"event":"start","alert":{"title":"Changed","body":"Body"},"attributes-type":"Attributes",
            "attributes":{"name":"Test Attribute"},"content-state":{"string":"Test","number":123},
            "timestamp":1672680658,"relevance-score":0.25}}
            """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testDismissalDate_helpers() {
        XCTAssertEqual(APNSLiveActivityDismissalDate.none, .init(dismissal: nil))
        XCTAssertEqual(APNSLiveActivityDismissalDate.immediately, .init(dismissal: 0))
        XCTAssertEqual(APNSLiveActivityDismissalDate.timeIntervalSince1970InSeconds(1_672_690_000), .init(dismissal: 1_672_690_000))
        XCTAssertEqual(
            APNSLiveActivityDismissalDate.date(Date(timeIntervalSince1970: 1_672_690_000.9)),
            .init(dismissal: 1_672_690_000)
        )
    }

    func testEncodeUpdate() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .update,
            timestamp: 1_672_680_658)

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"update","content-state":{"string":"Test","number":123},"timestamp":1672680658}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeUpdateStale() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .update,
            timestamp: 1_672_680_658,
            staleDate: 1_672_680_800)

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"update","content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "stale-date":1672680800}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeUpdateAlert() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .update,
            alert: .init(title: .raw("Hi"), body: .raw("Hello"), sound: .default),
            timestamp: 1_672_680_658
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"update", "alert": { "title": "Hi", "body": "Hello", "sound": "default" },\
            "content-state":{"string":"Test","number":123},"timestamp":1672680658}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeUpdateRelevanceScore() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .update,
            timestamp: 1_672_680_658,
            relevanceScore: 0.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"update","content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "relevance-score":0.5}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeUpdateLocalizedAlert() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .update,
            alert: .init(
                title: .localized(key: "%@ is knocked down!", arguments: ["Power Panda"]),
                body: .localized(key: "Use a potion to heal %@!", arguments: ["Power Panda"]),
                sound: .fileName("HeroDown.mp4")
            ),
            timestamp: 1_672_680_658
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"update","content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "alert":{
              "title":{"loc-key":"%@ is knocked down!","loc-args":["Power Panda"]},
              "body":{"loc-key":"Use a potion to heal %@!","loc-args":["Power Panda"]},
              "sound":"HeroDown.mp4"
            }}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeStartLocalizedAlert() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 1_672_680_658,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(
                title: .localized(key: "%@ is on an adventure!", arguments: ["Power Panda"]),
                body: .localized(key: "%@ found a sword!", arguments: ["Power Panda"]),
                sound: .fileName("chime.aiff")
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"start","attributes-type":"Attributes","attributes":{"name":"Test Attribute"},
            "content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "alert":{
              "title":{"loc-key":"%@ is on an adventure!","loc-args":["Power Panda"]},
              "body":{"loc-key":"%@ found a sword!","loc-args":["Power Panda"]},
              "sound":"chime.aiff"
            }}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeStartMixedRawAndLocalizedAlert() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 1_672_680_658,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(
                title: .raw("Hi"),
                body: .localized(key: "body-key", arguments: [])
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"start","attributes-type":"Attributes","attributes":{"name":"Test Attribute"},
            "content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "alert":{"title":"Hi","body":{"loc-key":"body-key","loc-args":[]}}}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeStart() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 1_672_680_658,
            staleDate: 1_672_680_800,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(title: .raw("Hi"), body: .raw("Hello"))
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"start", "alert": { "title": "Hi", "body": "Hello" }, "attributes-type": "Attributes", "attributes": {"name":"Test Attribute"},"content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "stale-date":1672680800}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeStartInputPushToken() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 1_672_680_658,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(title: .raw("Hi"), body: .raw("Hello")),
            inputPushMethod: .token
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let jsonObject = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let aps = jsonObject["aps"] as! NSDictionary
        XCTAssertEqual(aps["input-push-token"] as? Int, 1)
        XCTAssertNil(aps["input-push-channel"])
    }

    func testEncodeStartInputPushChannel() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 1_672_680_658,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(title: .raw("Hi"), body: .raw("Hello")),
            inputPushMethod: .channel("abc")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let jsonObject = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let aps = jsonObject["aps"] as! NSDictionary
        XCTAssertEqual(aps["input-push-channel"] as? String, "abc")
        XCTAssertNil(aps["input-push-token"])
    }

    func testEncodeStartNoInputPushMethod() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            timestamp: 1_672_680_658,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(title: .raw("Hi"), body: .raw("Hello"))
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let jsonObject = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let aps = jsonObject["aps"] as! NSDictionary
        XCTAssertNil(aps["input-push-token"])
        XCTAssertNil(aps["input-push-channel"])
    }

    func testEncodeStartViaTopic() throws {
        let notification = APNSStartLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            topic: "test.app.id.push-type.liveactivity",
            contentState: State(),
            timestamp: 1_672_680_658,
            attributes: Attributes(),
            attributesType: "Attributes",
            alert: .init(title: .raw("Hi"), body: .raw("Hello"))
        )

        XCTAssertEqual(notification.topic, "test.app.id.push-type.liveactivity")
    }

    func testEncodeEndNoDismiss() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .end,
            timestamp: 1_672_680_658)

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"end","content-state":{"string":"Test","number":123},"timestamp":1672680658}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncodeEndDismiss() throws {
        let notification = APNSLiveActivityNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "test.app.id",
            contentState: State(),
            event: .end,
            timestamp: 1_672_680_658,
            dismissalDate: .timeIntervalSince1970InSeconds(1_672_680_800))

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
            {"aps":{"event":"end","content-state":{"string":"Test","number":123},"timestamp":1672680658,
            "dismissal-date":1672680800}}
            """

        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 =
            try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!)
            as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }
}
