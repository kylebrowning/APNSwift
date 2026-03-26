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

/// Represents a broadcast channel configuration.
public struct APNSBroadcastChannel: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case messageStoragePolicy = "message-storage-policy"
        case pushType = "push-type"
    }

    /// The message storage policy for this channel.
    public let messageStoragePolicy: APNSBroadcastMessageStoragePolicy

    /// The push type for this broadcast channel.
    /// Currently only "LiveActivity" is supported for broadcast channels.
    public let pushType: String

    /// Creates a new broadcast channel configuration.
    ///
    /// - Parameter messageStoragePolicy: The storage policy for messages in this channel.
    public init(messageStoragePolicy: APNSBroadcastMessageStoragePolicy) {
        self.messageStoragePolicy = messageStoragePolicy
        self.pushType = "LiveActivity"
    }

    /// Internal initializer used for decoding responses that include channel ID.
    public init(messageStoragePolicy: APNSBroadcastMessageStoragePolicy, pushType: String = "LiveActivity") {
        self.messageStoragePolicy = messageStoragePolicy
        self.pushType = pushType
    }
}
