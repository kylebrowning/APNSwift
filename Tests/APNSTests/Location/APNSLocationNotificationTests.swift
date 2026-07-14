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

final class APNSLocationNotificationTests: XCTestCase {
    func testAppID() {
        let locationNotification = APNSLocationNotification(
            priority: .immediately,
            appID: "com.example.app"
        )

        XCTAssertEqual(locationNotification.topic, "com.example.app.location-query")
    }

    func testEncode() throws {
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
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }
}
