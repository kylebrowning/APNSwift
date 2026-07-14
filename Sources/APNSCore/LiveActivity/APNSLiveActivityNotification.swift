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

/// A live activity notification.
///
/// It is **important** that you do not encode anything with the key `aps`.
public struct APNSLiveActivityNotification<ContentState: Encodable & Sendable>: APNSMessage {
    enum CodingKeys: CodingKey {
        case aps
    }

    /// The fixed content to indicate that this is a background notification.
    private var aps: APNSLiveActivityNotificationAPSStorage<ContentState>

    /// Timestamp when sending notification
    public var timestamp: Int {
        get {
            return self.aps.timestamp
        }

        set {
            self.aps.timestamp = newValue
        }
    }

    /// Event type e.g. update
    public var event: APNSLiveActivityNotificationEvent {
        get {
            return APNSLiveActivityNotificationEvent(rawValue: self.aps.event)
        }

        set {
            self.aps.event = newValue.rawValue
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

    public var dismissalDate: APNSLiveActivityDismissalDate? {
        get {
            return .init(dismissal: self.aps.dismissalDate)
        }
        set {
            self.aps.dismissalDate = newValue?.dismissal
        }
    }

    /// Timestamp when the notification is marked as stale.
    public var staleDate: Int? {
        get {
            return self.aps.staleDate
        }
        set {
            self.aps.staleDate = newValue
        }
    }

    /// An alert that will be sent along with the notification.
    public var alert: APNSAlertNotificationContent? {
        get {
            return self.aps.alert
        }
        set {
            self.aps.alert = newValue
        }
    }

    /// The relevance score, a number that the system uses to sort the notifications from your app.
    public var relevanceScore: Double? {
        get {
            return self.aps.relevanceScore
        }
        set {
            self.aps.relevanceScore = newValue
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

    /// Initializes a new ``APNSLiveActivityNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///   - priority: The priority of the notification.
    ///   - appID: Your app’s bundle ID/app ID. This will be suffixed with `.push-type.liveactivity`.
    ///   - apnsID: A canonical UUID that identifies the notification.
    ///   - contentState: Updated content-state of live activity
    ///   - event: event type e.g. update
    ///   - alert: Optional alert content for the notification.
    ///   - timestamp: Timestamp when sending notification
    ///   - dismissalDate: Timestamp when to dismiss live notification when sent with `end`, if in the past
    ///    dismiss immediately
    ///   - staleDate: Timestamp when the notification is marked as stale
    ///   - relevanceScore: The relevance score, a number that the system uses to sort the notifications from your app.
    public init(
        expiration: APNSNotificationExpiration,
        priority: APNSPriority,
        appID: String,
        contentState: ContentState,
        event: APNSLiveActivityNotificationEvent,
        alert: APNSAlertNotificationContent? = nil,
        timestamp: Int,
        dismissalDate: APNSLiveActivityDismissalDate = .none,
        staleDate: Int? = nil,
        relevanceScore: Double? = nil,
        apnsID: UUID? = nil
    ) {
        self.init(
            expiration: expiration,
            priority: priority,
            topic: appID + ".push-type.liveactivity",
            apnsID: apnsID,
            contentState: contentState,
            event: event,
            alert: alert,
            timestamp: timestamp,
            dismissalDate: dismissalDate,
            staleDate: staleDate,
            relevanceScore: relevanceScore
        )
    }

    /// Initializes a new ``APNSLiveActivityNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///   - priority: The priority of the notification.
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.push-type.liveactivity`.
    ///   - apnsID: A canonical UUID that identifies the notification.
    ///   - contentState: Updated content-state of live activity
    ///   - event: event type e.g. update
    ///   - alert: Optional alert content for the notification.
    ///   - timestamp: Timestamp when sending notification
    ///   - dismissalDate: Timestamp when to dismiss live notification when sent with `end`, if in the past
    ///    dismiss immediately
    ///   - staleDate: Timestamp when the notification is marked as stale
    ///   - relevanceScore: The relevance score, a number that the system uses to sort the notifications from your app.
    public init(
        expiration: APNSNotificationExpiration,
        priority: APNSPriority,
        topic: String,
        apnsID: UUID? = nil,
        contentState: ContentState,
        event: APNSLiveActivityNotificationEvent,
        alert: APNSAlertNotificationContent? = nil,
        timestamp: Int,
        dismissalDate: APNSLiveActivityDismissalDate = .none,
        staleDate: Int? = nil,
        relevanceScore: Double? = nil
    ) {
        self.aps = APNSLiveActivityNotificationAPSStorage(
            timestamp: timestamp,
            event: event.rawValue,
            contentState: contentState,
            dismissalDate: dismissalDate.dismissal,
            staleDate: staleDate,
            alert: alert,
            relevanceScore: relevanceScore
        )
        self.apnsID = apnsID
        self.expiration = expiration
        self.priority = priority
        self.topic = topic
    }
}
