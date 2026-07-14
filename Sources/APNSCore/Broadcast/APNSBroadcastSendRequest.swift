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

/// Represents a request to publish a broadcast push notification.
///
/// Broadcast pushes are sent to the regular device-push host (``APNSEnvironment``), not the
/// channel-management host, at `POST /4/broadcasts/apps/<bundle ID>`. They are Live Activities only
/// and cannot be used to start an activity.
///
/// See: https://developer.apple.com/documentation/usernotifications/sending-broadcast-push-notification-requests-to-apns
public struct APNSBroadcastSendRequest<Message: APNSMessage>: Sendable {
    /// The message payload to broadcast.
    public let message: Message

    /// The base64-encoded channel ID to publish the broadcast on.
    public let channelID: String

    /// The app's bundle identifier used in the API path.
    public let bundleID: String

    /// The date when the notification is no longer valid and can be discarded.
    public let expiration: APNSNotificationExpiration

    /// The priority of the notification.
    public let priority: APNSPriority

    /// An optional request ID for tracking. If you omit this, APNs creates a new UUID and returns it in the response.
    public let apnsRequestID: UUID?

    /// Creates a broadcast send request.
    ///
    /// - Parameters:
    ///   - message: The message payload to broadcast.
    ///   - channelID: The base64-encoded channel ID to publish the broadcast on.
    ///   - bundleID: The app's bundle identifier used in the API path.
    ///   - expiration: The date when the notification is no longer valid and can be discarded.
    ///   - priority: The priority of the notification.
    ///   - apnsRequestID: An optional request ID for tracking.
    public init(
        message: Message,
        channelID: String,
        bundleID: String,
        expiration: APNSNotificationExpiration,
        priority: APNSPriority,
        apnsRequestID: UUID? = nil
    ) {
        self.message = message
        self.channelID = channelID
        self.bundleID = bundleID
        self.expiration = expiration
        self.priority = priority
        self.apnsRequestID = apnsRequestID
    }

    /// The HTTP headers required (and optional) by APNs for a broadcast send request.
    ///
    /// - Note: Unlike a regular device push, `apns-expiration` and `apns-priority` are always emitted
    /// since Apple requires both headers on broadcast requests.
    public var headers: [(String, String)] {
        var computedHeaders: [(String, String)] = []

        /// Channel ID
        computedHeaders.append(("apns-channel-id", channelID))

        /// Push type — broadcast only supports `liveactivity`.
        computedHeaders.append(("apns-push-type", "liveactivity"))

        /// Expiration — required by Apple, so `.none` is sent as `0`.
        computedHeaders.append(("apns-expiration", "\(expiration.expiration ?? 0)"))

        /// Priority — required by Apple.
        computedHeaders.append(("apns-priority", "\(priority.rawValue)"))

        /// Request ID
        if let apnsRequestID {
            computedHeaders.append(("apns-request-id", apnsRequestID.uuidString.lowercased()))
        }

        return computedHeaders
    }
}
