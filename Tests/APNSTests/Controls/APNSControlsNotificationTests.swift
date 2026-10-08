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

struct APNSControlsNotificationTests {
    @Test func appID() {
        let controlsNotification = APNSControlsNotification(appID: "com.example.app")
        #expect(controlsNotification.topic == "com.example.app.push-type.controls")
    }

    @Test func encode() throws {
        let controlsNotification = APNSControlsNotification(appID: "com.example.app")

        let encoder = JSONEncoder()
        let data = try encoder.encode(controlsNotification)

        let expectedJSONString = """
        {"aps":{"content-changed":true}}
        """
        let expectedData = try #require(expectedJSONString.data(using: .utf8))
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: expectedData) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }
}
