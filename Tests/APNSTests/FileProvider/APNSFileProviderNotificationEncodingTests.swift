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

final class APNSFileProviderNotificationEncodingTests: XCTestCase {
    func testEncode() throws {
        struct Payload: Encodable {
            let foo = "bar"
        }
        let notification = APNSFileProviderNotification(
            expiration: .immediately,
            topic: "com.example.app.pushkit.fileprovider",
            payload: Payload(),
            apnsID: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {"foo":"bar"}
        """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_whenEmptyPayload() throws {
        let notification = APNSFileProviderNotification(
            expiration: .immediately,
            appID: "com.example.app"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)

        let expectedJSONString = """
        {}
        """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }
}
