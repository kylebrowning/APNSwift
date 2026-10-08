//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2024 the APNSwift project authors
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

struct APNSBroadcastChannelTests {
    @Test(arguments: [
        (APNSBroadcastMessageStoragePolicy.mostRecentMessageStored, 1),
        (APNSBroadcastMessageStoragePolicy.noMessageStored, 0),
    ])
    func encode(policy: APNSBroadcastMessageStoragePolicy, rawPolicy: Int) throws {
        let channel = APNSBroadcastChannel(messageStoragePolicy: policy)
        let encoder = JSONEncoder()
        let data = try encoder.encode(channel)

        let expectedJSONString = """
        {"message-storage-policy":\(rawPolicy),"push-type":"LiveActivity"}
        """
        let expectedData = try #require(expectedJSONString.data(using: .utf8))
        let jsonObject1 = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let jsonObject2 = try #require(JSONSerialization.jsonObject(with: expectedData) as? NSDictionary)
        #expect(jsonObject1 == jsonObject2)
    }

    @Test func decode() throws {
        let jsonString = """
        {"message-storage-policy":1,"push-type":"LiveActivity"}
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let channel = try decoder.decode(APNSBroadcastChannel.self, from: data)

        #expect(channel.messageStoragePolicy == .mostRecentMessageStored)
        #expect(channel.pushType == "LiveActivity")
    }
}
