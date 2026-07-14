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

import APNSCore
import XCTest

final class APNSLiveActivityNotificationTests: XCTestCase {

    struct Attributes: Encodable {
        let name: String = "Test Attribute"
    }

    struct State: Encodable, Hashable {
        let string: String = "Test"
        let number: Int = 123
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
