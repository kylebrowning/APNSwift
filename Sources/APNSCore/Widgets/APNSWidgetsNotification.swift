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

/// A widget update notification.
public struct APNSWidgetsNotification: APNSMessage {
    @usableFromInline
    struct APS: Encodable, Sendable {
        enum CodingKeys: String, CodingKey {
            case contentAvailable = "content-changed"
        }

        let contentAvailable: Bool = true
    }

    @usableFromInline
    enum CodingKeys: CodingKey {
        case aps
    }

    /// The fixed content to indicate that this is a background notification.
    @usableFromInline
    internal let aps = APS()

    /// A canonical UUID that identifies the notification. If there is an error sending the notification,
    /// APNs uses this value to identify the notification to your server. The canonical form is 32 lowercase hexadecimal digits,
    /// displayed in five groups separated by hyphens in the form 8-4-4-4-12. An example UUID is as follows:
    /// `123e4567-e89b-12d3-a456-42665544000`.
    ///
    /// If you omit this, a new UUID is created by APNs and returned in the response.
    public var apnsID: UUID?

    /// The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.push-type.widgets`.
    public var topic: String

    /// Initializes a new ``APNSWidgetsNotification``.
    ///
    /// - Parameters:
    ///   - appID: Your app’s bundle ID/app ID. This will be suffixed with `.push-type.widgets`.
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        appID: String,
        apnsID: UUID? = nil
    ) {
        self.init(
            topic: appID + ".push-type.widgets",
            apnsID: apnsID
        )
    }

    /// Initializes a new ``APNSWidgetsNotification``.
    ///
    /// - Parameters:
    ///   - topic: The topic for the notification. In general, the topic is your app’s bundle ID/app ID suffixed with `.push-type.widgets`.
    ///   - apnsID: A canonical UUID that identifies the notification.
    @inlinable
    public init(
        topic: String,
        apnsID: UUID? = nil
    ) {
        self.topic = topic
        self.apnsID = apnsID
    }
}
