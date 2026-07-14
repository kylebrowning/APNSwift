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

final class APNSControlsNotificationTests: XCTestCase {
    func testAppID() {
        let controlsNotification = APNSControlsNotification(appID: "com.example.app")
        XCTAssertEqual(controlsNotification.topic, "com.example.app.push-type.controls")
    }

    func testEncode() throws {
        let controlsNotification = APNSControlsNotification(appID: "com.example.app")

        let encoder = JSONEncoder()
        let data = try encoder.encode(controlsNotification)

        let expectedJSONString = """
        {"aps":{"content-changed":true}}
        """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

}
