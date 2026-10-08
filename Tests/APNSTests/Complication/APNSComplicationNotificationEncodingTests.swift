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

struct APNSComplicationNotificationEncodingTests {
    @Test func encode() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSComplicationNotification(
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app.complication",
            payload: Payload(),
            apnsID: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"foo":"bar"}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func `Encode when empty payload`() throws {
        let notification = APNSComplicationNotification(
            expiration: .immediately,
            priority: .immediately,
            appID: "com.example.app"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }
}
