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

final class APNSBroadcastChannelListTests: XCTestCase {
    func testDecode() throws {
        let jsonString = """
        {"channels":["channel-1","channel-2","channel-3"]}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let channelList = try decoder.decode(APNSBroadcastChannelList.self, from: data)

        XCTAssertEqual(channelList.channels.count, 3)
        XCTAssertEqual(channelList.channels[0], "channel-1")
        XCTAssertEqual(channelList.channels[1], "channel-2")
        XCTAssertEqual(channelList.channels[2], "channel-3")
    }

    func testDecode_emptyList() throws {
        let jsonString = """
        {"channels":[]}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let channelList = try decoder.decode(APNSBroadcastChannelList.self, from: data)

        XCTAssertEqual(channelList.channels.count, 0)
    }
}
