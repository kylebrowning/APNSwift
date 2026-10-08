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

struct APNSBackgroundNotificationTests {
    @Test func encode() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSBackgroundNotification(
            expiration: .none,
            topic: "com.test.app",
            payload: Payload(),
            apnsID: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"foo":"bar","aps":{"content-available":1}}
        """
        let expectedData = try #require(expectedJSONString.data(using: .utf8))
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: expectedData) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when APS key in payload`() throws {
        struct Payload: Encodable {
            let aps = "foo"
        }
        let notification = APNSBackgroundNotification(
            expiration: .none,
            topic: "com.test.app",
            payload: Payload(),
            apnsID: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"aps":{"content-available":1}}
        """
        let expectedData = try #require(expectedJSONString.data(using: .utf8))
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: expectedData) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode empty payload init`() throws {
        let apnsID = UUID()
        let notification = APNSBackgroundNotification(
            expiration: .immediately,
            topic: "com.example.app",
            apnsID: apnsID
        )
        #expect(notification.apnsID == apnsID)
        #expect(notification.topic == "com.example.app")

        let data = try JSONEncoder().encode(notification)
        let expectedJSONString = """
        {"aps":{"content-available":1}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

}
