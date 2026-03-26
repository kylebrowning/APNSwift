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

/// A notification that starts a live activity
///
/// It is **important** that you do not encode anything with the key `aps`.
public struct APNSStartLiveActivityNotification<Attributes: Encodable & Sendable, ContentState: Encodable & Sendable>:
    APNSMessage
{
    enum CodingKeys: CodingKey {
        case aps
    }

    /// The fixed content to indicate that this is a background notification.
    private var aps: APNSStartLiveActivityNotificationAPSStorage<Attributes, ContentState>

    /// Timestamp when sending notification
    public var timestamp: Int {
        get {
            return self.aps.timestamp
        }

        set {
            self.aps.timestamp = newValue
        }
    }

    public var alert: APNSAlertNotificationContent {
        get {
            return self.aps.alert
        }

        set {
            self.aps.alert = newValue
        }
    }

    /// The dynamic content of a Live Activity.
    public var contentState: ContentState {
        get {
            return self.aps.contentState
        }

        set {
            self.aps.contentState = newValue
        }
    }

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

    /// The priority of the notification.
    public var priority: APNSPriority

    /// The topic for the notification. In general, the topic is your app’s bundle ID/app ID.
    public var topic: String

    /// Initializes a new ``APNSStartLiveActivityNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///   - priority: The priority of the notification.
    ///   - appID: Your app’s bundle ID/app ID. This will be suffixed with `.push-type.liveactivity`.
    ///   - contentState: Updated content-state of live activity
    ///   - timestamp: Timestamp when sending notification
    ///   - staleDate: Timestamp when the notification is marked as stale
    ///   - apnsID: A canonical UUID that identifies the notification.
    ///   - attributes: The ActivityAttributes of the live activity to start
    ///   - attributesType: The type name of the ActivityAttributes you want to send
    ///   - alert: An alert that will be sent along with the notification
    public init(
        expiration: APNSNotificationExpiration,
        priority: APNSPriority,
        appID: String,
        contentState: ContentState,
        timestamp: Int,
        staleDate: Int? = nil,
        apnsID: UUID? = nil,
        attributes: Attributes,
        attributesType: String,
        alert: APNSAlertNotificationContent
    ) {
      self.aps = APNSStartLiveActivityNotificationAPSStorage(
          timestamp: timestamp,
          contentState: contentState,
          staleDate: staleDate,
          alert: alert,
          attributes: attributes,
          attributesType: attributesType
			)
			self.apnsID = apnsID
			self.expiration = expiration
			self.priority = priority
			self.topic = appID + ".push-type.liveactivity"
    }
}
