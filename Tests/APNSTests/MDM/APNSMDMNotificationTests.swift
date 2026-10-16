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

struct APNSMDMNotificationTests {
    @Test func encode() throws {
        let notification = APNSMDMNotification(
            topic: "com.apple.mgmt.External.3b3d5f2a-4b7c-4e1d-9f0a-2c9d8e7f6a5b",
            pushMagic: "PushMagicValue"
        )
        #expect(notification.topic == "com.apple.mgmt.External.3b3d5f2a-4b7c-4e1d-9f0a-2c9d8e7f6a5b")

        let data = try JSONEncoder().encode(notification)

        let expectedJSONString = """
        {"mdm":"PushMagicValue"}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }
}
