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

/// A background notification.
///
/// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
/// It is **important** that you do not encode anything with the key `aps`.
public struct APNSBackgroundNotification<Payload: Encodable & Sendable>: APNSMessage {
    @usableFromInline
    struct APS: Encodable, Sendable {
        enum CodingKeys: String, CodingKey {
            case contentAvailable = "content-available"
        }

        let contentAvailable: Int = 1
    }

    @usableFromInline
    enum CodingKeys: CodingKey {
        case aps
    }

    /// The fixed content to indicate that this is a background notification.
    @usableFromInline
    /* private */ internal let aps = APS()

    /// A canonical UUID that identifies the notification. If there is an error sending the notification,
    /// APNs uses this value to identify the notification to your server. The canonical form is 32 lowercase hexadecimal digits,
    /// displayed in five groups separated by hyphens in the form 8-4-4-4-12. An example UUID is as follows:
    /// `123e4567-e89b-12d3-a456-42665544000`.
    ///
    /// If you omit this, a new UUID is created by APNs and returned in the response.
    public var apnsID: UUID?

    /// The date when the notification is no longer valid and can be discarded. If this value is not `none`,
    /// APNs stores the notification and tries to deliver it at least once,
    /// repeating the attempt as needed if it is unable to deliver the notification the first time.
    /// If the value is `immediately`, APNs treats the notification as if it expires immediately
    /// and does not store the notification or attempt to redeliver it.
    public var expiration: APNSNotificationExpiration

    /// The topic for the notification. In general, the topic is your app’s bundle ID/app ID.
    public var topic: String

    /// Your custom payload.
    public var payload: Payload

    /// Initializes a new ``APNSBackgroundNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - payload: Your custom payload.
    ///
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID.
    ///
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        expiration: APNSNotificationExpiration,
        topic: String,
        payload: Payload,
        apnsID: UUID? = nil
    ) {
        self.payload = payload
        self.apnsID = apnsID
        self.expiration = expiration
        self.topic = topic
    }

    @inlinable
    public func encode(to encoder: Encoder) throws {
        // First we encode the user payload since this might use the `aps` key
        // and we override it afterward.
        try self.payload.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.aps, forKey: .aps)
    }
}

extension APNSBackgroundNotification where Payload == EmptyPayload {
    public init(
        expiration: APNSNotificationExpiration,
        topic: String,
        apnsID: UUID? = nil
    ) {
        self.init(
            expiration: expiration,
            topic: topic,
            payload: EmptyPayload(),
            apnsID: apnsID
        )
    }
}
