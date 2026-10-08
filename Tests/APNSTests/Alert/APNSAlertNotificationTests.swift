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
import Foundation
import Testing

struct APNSAlertNotificationTests {
    @Test func encode() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "",
            payload: Payload()
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"foo":"bar","aps":{"alert":{"title":"title"}}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when APS key in payload`() throws {
        struct Payload: Encodable {
            let aps = "foo"
        }
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "",
            payload: Payload()
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"aps":{"alert":{"title":"title"}}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when default sound`() throws {
        struct Payload: Encodable {
            let payload = "payload"
        }
        let notification = APNSAlertNotification(
            alert: .init(
                title: .raw("title"),
                subtitle: .localized(
                    key: "subtitle-key",
                    arguments: ["arg1"]
                ),
                body: .raw("body"),
                launchImage: "launchimage"
            ),
            expiration: .timeIntervalSince1970InSeconds(1_652_693_147),
            priority: .consideringDevicePower,
            topic: "topic",
            payload: Payload(),
            badge: 1,
            sound: .default,
            threadID: "threadID",
            category: "category",
            mutableContent: 1,
            targetContentID: "targetContentID",
            interruptionLevel: .critical,
            relevanceScore: 1,
            apnsID: .init()
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {\"payload\":\"payload\",\"aps\":{\"category\":\"category\",\"relevance-score\":1,\"badge\":1,\"target-content-id\":\"targetContentID\",\"sound\":\"default\",\"interruption-level\":\"critical\",\"alert\":{\"body\":\"body\",\"subtitle-loc-key\":\"subtitle-key\",\"title\":\"title\",\"launch-image\":\"launchimage\",\"subtitle-loc-args\":[\"arg1\"]},\"thread-id\":\"threadID\",\"mutable-content\":1}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when critical sound`() throws {
        struct Payload: Encodable {
            let payload = "payload"
        }
        let notification = APNSAlertNotification(
            alert: .init(
                title: .raw("title"),
                subtitle: .localized(
                    key: "subtitle-key",
                    arguments: ["arg1"]
                ),
                body: .raw("body"),
                launchImage: "launchimage"
            ),
            expiration: .timeIntervalSince1970InSeconds(1_652_693_147),
            priority: .consideringDevicePower,
            topic: "topic",
            payload: Payload(),
            badge: 1,
            sound: .critical(fileName: "file", volume: 1),
            threadID: "threadID",
            category: "category",
            mutableContent: 1,
            targetContentID: "targetContentID",
            interruptionLevel: .critical,
            relevanceScore: 1,
            apnsID: .init()
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {\"payload\":\"payload\",\"aps\":{\"category\":\"category\",\"relevance-score\":1,\"badge\":1,\"target-content-id\":\"targetContentID\",\"sound\":{\"name\":\"file\",\"volume\":1,\"critical\":1},\"interruption-level\":\"critical\",\"alert\":{\"body\":\"body\",\"subtitle-loc-key\":\"subtitle-key\",\"title\":\"title\",\"launch-image\":\"launchimage\",\"subtitle-loc-args\":[\"arg1\"]},\"thread-id\":\"threadID\",\"mutable-content\":1}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when filter criteria`() throws {
        struct Payload: Encodable {
            let payload = "payload"
        }
        let notification = APNSAlertNotification(
            alert: .init(
                title: .raw("title"),
                subtitle: .localized(
                    key: "subtitle-key",
                    arguments: ["arg1"]
                ),
                body: .raw("body"),
                launchImage: "launchimage"
            ),
            expiration: .timeIntervalSince1970InSeconds(1_652_693_147),
            priority: .consideringDevicePower,
            topic: "topic",
            payload: Payload(),
            badge: 1,
            sound: .default,
            threadID: "threadID",
            category: "category",
            mutableContent: 1,
            targetContentID: "targetContentID",
            interruptionLevel: .critical,
            relevanceScore: 1,
            filterCriteria: "user123",
            apnsID: .init()
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {\"payload\":\"payload\",\"aps\":{\"category\":\"category\",\"relevance-score\":1,\"filter-criteria\":\"user123\",\"badge\":1,\"target-content-id\":\"targetContentID\",\"sound\":\"default\",\"interruption-level\":\"critical\",\"alert\":{\"body\":\"body\",\"subtitle-loc-key\":\"subtitle-key\",\"title\":\"title\",\"launch-image\":\"launchimage\",\"subtitle-loc-args\":[\"arg1\"]},\"thread-id\":\"threadID\",\"mutable-content\":1}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when localized title and body`() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSAlertNotification(
            alert: .init(
                title: .localized(key: "title-key", arguments: ["title-arg"]),
                body: .localized(key: "body-key", arguments: ["body-arg1", "body-arg2"])
            ),
            expiration: .immediately,
            priority: .immediately,
            topic: "",
            payload: Payload()
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"foo":"bar","aps":{"alert":{"title-loc-key":"title-key","title-loc-args":["title-arg"],"loc-key":"body-key","loc-args":["body-arg1","body-arg2"]}}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)

        let alertDict = try #require((jsonObject1["aps"] as? NSDictionary)?["alert"] as? NSDictionary)
        #expect(alertDict["title"] == nil)
        #expect(alertDict["body"] == nil)
    }

    @Test func `Encode when file name sound`() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "",
            payload: Payload(),
            sound: .fileName("horn.aiff")
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"foo":"bar","aps":{"alert":{"title":"title"},"sound":"horn.aiff"}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)

        let aps = try #require(jsonObject1["aps"] as? NSDictionary)
        #expect(aps["sound"] as? String == "horn.aiff")
    }

    @Test(arguments: [
        (APNSAlertNotificationInterruptionLevel.passive, "passive"),
        (.active, "active"),
        (.timeSensitive, "time-sensitive"),
    ])
    func `Encode interruption levels`(level: APNSAlertNotificationInterruptionLevel, expectedRawValue: String) throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "",
            payload: Payload(),
            interruptionLevel: level
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let jsonObject = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let aps = try #require(jsonObject["aps"] as? NSDictionary)
        #expect(aps["interruption-level"] as? String == expectedRawValue)
    }

    @Test func `Setters are reflected in encoded APS`() throws {
        var notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app"
        )

        notification.alert = .init(title: .raw("new title"), body: .raw("body"))
        notification.badge = 3
        notification.sound = .default
        notification.threadID = "thread"
        notification.category = "category"
        notification.mutableContent = 1
        notification.targetContentID = "target"
        notification.interruptionLevel = .timeSensitive
        notification.relevanceScore = 0.5
        notification.filterCriteria = "filter"

        #expect(notification.badge == 3)
        #expect(notification.sound == .default)
        #expect(notification.threadID == "thread")
        #expect(notification.category == "category")
        #expect(notification.mutableContent == 1)
        #expect(notification.targetContentID == "target")
        #expect(notification.interruptionLevel == .timeSensitive)
        #expect(notification.relevanceScore == 0.5)
        #expect(notification.filterCriteria == "filter")

        let data = try JSONEncoder().encode(notification)
        let expectedJSONString = """
        {"aps":{
          "alert":{"title":"new title","body":"body"},
          "badge":3,
          "sound":"default",
          "thread-id":"thread",
          "category":"category",
          "mutable-content":1,
          "target-content-id":"target",
          "interruption-level":"time-sensitive",
          "relevance-score":0.5,
          "filter-criteria":"filter"
        }}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Empty payload init encodes every APS field`() throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            badge: 1,
            sound: .default,
            threadID: "thread",
            category: "category",
            mutableContent: 1,
            targetContentID: "target",
            interruptionLevel: .critical,
            relevanceScore: 1,
            filterCriteria: "filter"
        )

        let data = try JSONEncoder().encode(notification)
        let expectedJSONString = """
        {"aps":{
          "alert":{"title":"title"},
          "badge":1,
          "sound":"default",
          "thread-id":"thread",
          "category":"category",
          "mutable-content":1,
          "target-content-id":"target",
          "interruption-level":"critical",
          "relevance-score":1,
          "filter-criteria":"filter"
        }}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

}
