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
import XCTest

final class APNSBroadcastChannelTests: XCTestCase {
    func testEncode() throws {
        let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
        let encoder = JSONEncoder()
        let data = try encoder.encode(channel)

        let expectedJSONString = """
        {"message-storage-policy":1,"push-type":"LiveActivity"}
        """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testEncode_noMessageStored() throws {
        let channel = APNSBroadcastChannel(messageStoragePolicy: .noMessageStored)
        let encoder = JSONEncoder()
        let data = try encoder.encode(channel)

        let expectedJSONString = """
        {"message-storage-policy":0,"push-type":"LiveActivity"}
        """
        let jsonObject1 = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let jsonObject2 = try JSONSerialization.jsonObject(with: expectedJSONString.data(using: .utf8)!) as! NSDictionary
        XCTAssertEqual(jsonObject1, jsonObject2)
    }

    func testDecode() throws {
        let jsonString = """
        {"message-storage-policy":1,"push-type":"LiveActivity"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let channel = try decoder.decode(APNSBroadcastChannel.self, from: data)

        XCTAssertEqual(channel.messageStoragePolicy, .mostRecentMessageStored)
        XCTAssertEqual(channel.pushType, "LiveActivity")
    }
}
