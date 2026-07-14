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

final class APNSAlertNotificationTests: XCTestCase {
    func testEncode() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_whenAPSKeyInPayload() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_whenDefaultSound() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_whenCriticalSound() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_whenFilterCriteria() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_whenLocalizedTitleAndBody() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)

        let alertDict = try XCTUnwrap((jsonObject1["aps"] as? NSDictionary)?["alert"] as? NSDictionary)
        XCTAssertNil(alertDict["title"])
        XCTAssertNil(alertDict["body"])
    }

    func testEncode_whenFileNameSound() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)

        let aps = try XCTUnwrap(jsonObject1["aps"] as? NSDictionary)
        XCTAssertEqual(aps["sound"] as? String, "horn.aiff")
    }

    func testEncode_interruptionLevels() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }

        let levels: [(APNSAlertNotificationInterruptionLevel, String)] = [
            (.passive, "passive"),
            (.active, "active"),
            (.timeSensitive, "time-sensitive"),
        ]

        for (level, expectedRawValue) in levels {
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

            let jsonObject = try JSONSerialization.jsonObject(with: data) as! NSDictionary
            let aps = try XCTUnwrap(jsonObject["aps"] as? NSDictionary)
            XCTAssertEqual(aps["interruption-level"] as? String, expectedRawValue)
        }
    }
}
