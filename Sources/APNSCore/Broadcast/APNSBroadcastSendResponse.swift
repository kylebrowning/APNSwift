//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2025 the APNSwift project authors
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

/// Represents a response from publishing a broadcast push notification.
public struct APNSBroadcastSendResponse: Sendable, Hashable {
    /// The request ID returned by APNs, either echoing the one sent in the request or a newly generated one.
    public let apnsRequestID: UUID?

    /// A unique ID for the broadcast notification, as determined by the APNs servers.
    public let apnsUniqueID: UUID?

    public init(apnsRequestID: UUID?, apnsUniqueID: UUID?) {
        self.apnsRequestID = apnsRequestID
        self.apnsUniqueID = apnsUniqueID
    }
}
