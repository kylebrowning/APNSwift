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

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// The response of a successful APNs request.
public struct APNSResponse: Hashable, Sendable {
    /// The same value as the `apnsID` send in the request.
    ///
    /// Use this value to identify the notification. If you don’t specify an `apnsID` in your request,
    /// APNs creates a new `UUID` and returns it in this header.
    public var apnsID: UUID?
    
    /// A unique ID for the notification used for development, as determined by the APNs servers.
    ///
    /// In the development or sandbox environement, this value can be used to look up information about notifications on the [Push Notifications Console](https://icloud.developer.apple.com/dashboard/notifications). This value is not provided in the production environement.
    public var apnsUniqueID: UUID?

    /// Initializes a new ``APNSResponse``.
    ///
    /// - Parameter apnsID: The same value as the `apnsID` send in the request.
    /// - Parameter apnsUniqueID: A unique ID for the notification used only in the development environment.
    public init(apnsID: UUID? = nil, apnsUniqueID: UUID? = nil) {
        self.apnsID = apnsID
        self.apnsUniqueID = apnsUniqueID
    }
}

/// The [Push Notifications Console](https://icloud.developer.apple.com/dashboard/notifications) expects IDs to be lowercased, so prep them ahead of time here to make it easier for users to copy and paste these IDs.
extension APNSResponse: CustomStringConvertible {
    public var description: String {
        "APNSResponse(apns-id: \(apnsID?.uuidString.lowercased() ?? "nil"), apns-unique-id: \(apnsUniqueID?.uuidString.lowercased() ?? "nil"))"
    }
}
