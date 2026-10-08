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

struct APNSLocationNotificationTests {
    @Test func appID() {
        let locationNotification = APNSLocationNotification(
            priority: .immediately,
            appID: "com.example.app"
        )

        #expect(locationNotification.topic == "com.example.app.location-query")
    }

    @Test func encode() throws {
        let notification = APNSLocationNotification(
            priority: .immediately,
            topic: "com.example.app.location-query",
            apnsID: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"aps":{}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }
}
