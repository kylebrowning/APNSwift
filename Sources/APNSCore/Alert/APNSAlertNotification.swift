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

/// An alert notification.
///
/// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
/// It is **important** that you do not encode anything with the key `aps`.
public struct APNSAlertNotification<Payload: Encodable & Sendable>: APNSMessage, Sendable {
    enum CodingKeys: CodingKey {
        case aps
    }

    /// The fixed content to indicate that this is a background notification.
    private var aps = APNSAlertNotificationAPSStorage(alert: .init())

    /// The information for displaying an alert.
    public var alert: APNSAlertNotificationContent {
        get {
            self.aps.alert
        }
        set {
            self.aps.alert = newValue
        }
    }

    /// The number to display in a badge on your app’s icon.
    public var badge: Int? {
        get {
            self.aps.badge
        }
        set {
            self.aps.badge = newValue
        }
    }

    /// The sound to play for your alert.
    public var sound: APNSAlertNotificationSound? {
        get {
            self.aps.sound
        }
        set {
            self.aps.sound = newValue
        }
    }

    /// An app-specific identifier for grouping related notifications.
    ///
    /// This value corresponds to the `threadIdentifier` property in the `UNNotificationContent` object.
    public var threadID: String? {
        get {
            self.aps.threadID
        }
        set {
            self.aps.threadID = newValue
        }
    }

    /// The notification’s type.
    ///
    /// This string must correspond to the `identifier` of one of the `UNNotificationCategory` objects you register at launch time.
    public var category: String? {
        get {
            self.aps.category
        }
        set {
            self.aps.category = newValue
        }
    }

    /// The notification service app extension flag.
    ///
    /// If the value is `1`, the system passes the notification to your notification service app extension before delivery.
    /// Use your extension to modify the notification’s content.
    /// Semantically this would make sense to be a Bool. However, APNS accepts any number here so
    /// we need to allow this as well.
    public var mutableContent: Double? {
        get {
            self.aps.mutableContent
        }
        set {
            self.aps.mutableContent = newValue
        }
    }

    /// The identifier of the window brought forward.
    ///
    /// The value of this key will be populated on the `UNNotificationContent` object created from the push payload.
    /// Access the value using the `UNNotificationContent` object’s `targetContentIdentifier` property.
    public var targetContentID: String? {
        get {
            self.aps.targetContentID
        }
        set {
            self.aps.targetContentID = newValue
        }
    }

    /// A string that indicates the importance and delivery timing of a notification.
    public var interruptionLevel: APNSAlertNotificationInterruptionLevel? {
        get {
            self.aps.interruptionLevel
        }
        set {
            self.aps.interruptionLevel = newValue
        }
    }

    /// The relevance score, a number between `0` and `1`, that the system uses to sort the notifications from your app.
    ///
    /// The highest score gets featured in the notification summary
    public var relevanceScore: Double? {
        get {
            self.aps.relevanceScore
        }
        set {
            self.aps.relevanceScore = newValue
        }
    }

    /// The criteria the system evaluates to determine if it displays the notification in the current Focus.
    public var filterCriteria: String? {
        get {
            self.aps.filterCriteria
        }
        set {
            self.aps.filterCriteria = newValue
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
    
    /// The collapse identifier
    public var collapseID: String?

    /// Your custom payload.
    public var payload: Payload

    /// Initializes a new ``APNSAlertNotification``.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - alert: The information for displaying an alert.
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///   - priority: The priority of the notification.
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID.
    ///   - payload: Your custom payload.
    ///   - badge: The number to display in a badge on your app’s icon.
    ///   - sound: The sound to play for your alert.
    ///   - threadID: An app-specific identifier for grouping related notifications.
    ///   - category: The notification’s type.
    ///   - mutableContent: The notification service app extension flag.
    ///   - targetContentID: The identifier of the window brought forward.
    ///   - interruptionLevel: A string that indicates the importance and delivery timing of a notification.
    ///   - relevanceScore: The relevance score, a number between `0` and `1`, that the system uses to sort the notifications from your app.
    ///   - filterCriteria: The criteria the system evaluates to determine if it displays the notification in the current Focus.
    ///   - apnsID: A canonical UUID that identifies the notification.
    public init(
        alert: APNSAlertNotificationContent,
        expiration: APNSNotificationExpiration,
        priority: APNSPriority,
        topic: String,
        payload: Payload,
        badge: Int? = nil,
        sound: APNSAlertNotificationSound? = nil,
        threadID: String? = nil,
        category: String? = nil,
        mutableContent: Double? = nil,
        targetContentID: String? = nil,
        interruptionLevel: APNSAlertNotificationInterruptionLevel? = nil,
        relevanceScore: Double? = nil,
        filterCriteria: String? = nil,
        apnsID: UUID? = nil
    ) {
        self.aps = APNSAlertNotificationAPSStorage(
            alert: alert,
            badge: badge,
            sound: sound,
            threadID: threadID,
            category: category,
            mutableContent: mutableContent,
            targetContentID: targetContentID,
            interruptionLevel: interruptionLevel,
            relevanceScore: relevanceScore,
            filterCriteria: filterCriteria
        )
        self.apnsID = apnsID
        self.expiration = expiration
        self.priority = priority
        self.topic = topic
        self.payload = payload
    }

    public func encode(to encoder: Encoder) throws {
        // First we encode the user payload since this might use the `aps` key
        // and we override it afterward.
        try self.payload.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.aps, forKey: .aps)
    }
}

extension APNSAlertNotification where Payload == EmptyPayload {
    /// Initializes a new ``APNSAlertNotification`` with an empty Payload.
    ///
    /// - Important: Your dynamic payload will get encoded to the root of the JSON payload that is send to APNs.
    /// It is **important** that you do not encode anything with the key `aps`
    ///
    /// - Parameters:
    ///   - alert: The information for displaying an alert.
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///   - priority: The priority of the notification.
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID.
    ///   - badge: The number to display in a badge on your app’s icon.
    ///   - sound: The sound to play for your alert.
    ///   - threadID: An app-specific identifier for grouping related notifications.
    ///   - category: The notification’s type.
    ///   - mutableContent: The notification service app extension flag.
    ///   - targetContentID: The identifier of the window brought forward.
    ///   - interruptionLevel: A string that indicates the importance and delivery timing of a notification.
    ///   - relevanceScore: The relevance score, a number between `0` and `1`, that the system uses to sort the notifications from your app.
    ///   - filterCriteria: The criteria the system evaluates to determine if it displays the notification in the current Focus.
    ///   - apnsID: A canonical UUID that identifies the notification.
    public init(
        alert: APNSAlertNotificationContent,
        expiration: APNSNotificationExpiration,
        priority: APNSPriority,
        topic: String,
        badge: Int? = nil,
        sound: APNSAlertNotificationSound? = nil,
        threadID: String? = nil,
        category: String? = nil,
        mutableContent: Double? = nil,
        targetContentID: String? = nil,
        interruptionLevel: APNSAlertNotificationInterruptionLevel? = nil,
        relevanceScore: Double? = nil,
        filterCriteria: String? = nil,
        apnsID: UUID? = nil
    ) {
        self.aps = APNSAlertNotificationAPSStorage(
            alert: alert,
            badge: badge,
            sound: sound,
            threadID: threadID,
            category: category,
            mutableContent: mutableContent,
            targetContentID: targetContentID,
            interruptionLevel: interruptionLevel,
            relevanceScore: relevanceScore,
            filterCriteria: filterCriteria
        )
        self.apnsID = apnsID
        self.expiration = expiration
        self.priority = priority
        self.topic = topic
        self.payload = EmptyPayload()
    }
}
