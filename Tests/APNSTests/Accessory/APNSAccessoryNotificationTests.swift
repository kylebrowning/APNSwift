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

struct APNSAccessoryNotificationTests {
    @Test func appID() {
        let notification = Self.makeNotification()
        #expect(notification.topic == "com.example.app.push-type.accessory")
        #expect(notification.encryptedData == "ZW5jcnlwdGVk")
        #expect(notification.sessionIdentifier == "session-1")
        #expect(notification.keyID == "a2V5")
        #expect(notification.messageIndex == 42)
    }

    @Test func encode() throws {
        let data = try JSONEncoder().encode(Self.makeNotification())

        let expectedJSONString = """
        {"aps":{"encryptedData":"ZW5jcnlwdGVk","sessionIdentifier":"session-1","keyID":"a2V5","messageIndex":"42"}}
        """
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: Data(expectedJSONString.utf8)) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    private static func makeNotification() -> APNSAccessoryNotification {
        APNSAccessoryNotification(
            appID: "com.example.app",
            encryptedData: "ZW5jcnlwdGVk",
            sessionIdentifier: "session-1",
            keyID: "a2V5",
            messageIndex: 42
        )
    }
}
