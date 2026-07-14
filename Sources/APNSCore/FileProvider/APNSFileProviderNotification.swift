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

/// A file provider notification.
public struct APNSFileProviderNotification<Payload: Encodable & Sendable>: APNSMessage {
    /// A canonical UUID that identifies the notification. If there is an error sending the notification,
    /// APNs uses this value to identify the notification to your server. The canonical form is 32 lowercase hexadecimal digits,
    /// displayed in five groups separated by hyphens in the form 8-4-4-4-12. An example UUID is as follows:
    /// `123e4567-e89b-12d3-a456-42665544000`.
    ///
    /// If you omit this, a new UUID is created by APNs and returned in the response.
    public var apnsID: UUID?

    /// The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.voip`.
    public var topic: String

    /// The date when the notification is no longer valid and can be discarded. If this value is not `none`,
    /// APNs stores the notification and tries to deliver it at least once,
    /// repeating the attempt as needed if it is unable to deliver the notification the first time.
    /// If the value is `immediately`, APNs treats the notification as if it expires immediately
    /// and does not store the notification or attempt to redeliver it.
    public var expiration: APNSNotificationExpiration

    /// Your custom payload.
    public var payload: Payload

    /// Initializes a new ``APNSFileProviderNotification``.
    ///
    /// - Parameters:
    ///   - expiration: The date when the notification is no longer valid and can be discarded
    ///   - appID: Your app’s bundle ID/app ID. This will be suffixed with `.pushkit.fileprovider`.
    ///   - payload: Your custom payload.
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        expiration: APNSNotificationExpiration,
        appID: String,
        payload: Payload,
        apnsID: UUID? = nil
    ) {
        self.init(
            expiration: expiration,
            topic: appID + ".pushkit.fileprovider",
            payload: payload,
            apnsID: apnsID
        )
    }

    /// Initializes a new ``APNSFileProviderNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - expiration: The date when the notification is no longer valid and can be discarded
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.pushkit.fileprovider`.
    ///   - payload: Your custom payload.
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        expiration: APNSNotificationExpiration,
        topic: String,
        payload: Payload,
        apnsID: UUID? = nil
    ) {
        self.expiration = expiration
        self.topic = topic
        self.payload = payload
        self.apnsID = apnsID
    }

    @inlinable
    public func encode(to encoder: Encoder) throws {
        try self.payload.encode(to: encoder)
    }
}

extension APNSFileProviderNotification where Payload == EmptyPayload {
    /// Initializes a new ``APNSFileProviderNotification`` with an EmptyPayload.
    ///
    /// - Parameters:
    ///   - expiration: The date when the notification is no longer valid and can be discarded
    ///   - appID: Your app’s bundle ID/app ID. This will be suffixed with `.pushkit.fileprovider`.
    ///   - payload: Your custom payload.
    ///   - apnsID: A canonical UUID that identifies the notification.
    public init(
        expiration: APNSNotificationExpiration,
        appID: String,
        apnsID: UUID? = nil
    ) {
        self.init(
            expiration: expiration,
            topic: appID + ".pushkit.fileprovider",
            payload: EmptyPayload(),
            apnsID: apnsID
        )
    }
}
