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

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// Represents a response from a broadcast channel operation.
public struct APNSBroadcastResponse<Body: Decodable>: Sendable where Body: Sendable {
    /// The request ID returned by APNs.
    public let apnsRequestID: UUID?

    /// The channel ID returned by APNs.
    public let channelID: String?

    /// The response body.
    public let body: Body?

    public init(apnsRequestID: UUID?, channelID: String?, body: Body?) {
        self.apnsRequestID = apnsRequestID
        self.channelID = channelID
        self.body = body
    }
}
