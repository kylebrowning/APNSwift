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

struct APNSBroadcastChannelListTests {
    @Test func decode() throws {
        let jsonString = """
        {"channels":["channel-1","channel-2","channel-3"]}
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let channelList = try decoder.decode(APNSBroadcastChannelList.self, from: data)

        #expect(channelList.channels.count == 3)
        #expect(channelList.channels[0] == "channel-1")
        #expect(channelList.channels[1] == "channel-2")
        #expect(channelList.channels[2] == "channel-3")
    }

    @Test func `Decode empty list`() throws {
        let jsonString = """
        {"channels":[]}
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let channelList = try decoder.decode(APNSBroadcastChannelList.self, from: data)

        #expect(channelList.channels.count == 0)
    }
}
