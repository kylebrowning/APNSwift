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

/// A location notification.
public struct APNSLocationNotification: APNSMessage {
    /// A canonical UUID that identifies the notification. If there is an error sending the notification,
    /// APNs uses this value to identify the notification to your server. The canonical form is 32 lowercase hexadecimal digits,
    /// displayed in five groups separated by hyphens in the form 8-4-4-4-12. An example UUID is as follows:
    /// `123e4567-e89b-12d3-a456-42665544000`.
    ///
    /// If you omit this, a new UUID is created by APNs and returned in the response.
    public var apnsID: UUID?

    /// The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.location-query`.
    public var topic: String

    /// The priority of the notification.
    public var priority: APNSPriority

    /// Initializes a new ``APNSLocationNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - priority: The priority of the notification.
    ///   - appID: Your app’s bundle ID/app ID. This will be suffixed with `.location-query`.
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        priority: APNSPriority,
        appID: String,
        apnsID: UUID? = nil
    ) {
        self.init(
            priority: priority,
            topic: appID + ".location-query",
            apnsID: apnsID
        )
    }

    /// Initializes a new ``APNSLocationNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - priority: The priority of the notification.
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.location-query`.
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        priority: APNSPriority,
        topic: String,
        apnsID: UUID? = nil
    ) {
        self.priority = priority
        self.topic = topic
        self.apnsID = apnsID
    }
}
