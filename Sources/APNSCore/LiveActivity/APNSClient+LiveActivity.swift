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

extension APNSClientProtocol {
    /// Sends a live activity notification.
    ///
    /// - Parameters:
    ///   - notification: The notification to send.
    ///
    ///   - deviceToken: The hexadecimal bytes use to send live activity notification. Your app receives the bytes for this activity token
    ///    from `pushTokenUpdates` async property of a live activity.
    ///
    @discardableResult
    @inlinable
    public func sendLiveActivityNotification<ContentState: Encodable>(
        _ notification: APNSLiveActivityNotification<ContentState>,
        deviceToken: String
    ) async throws -> APNSResponse {
        let request = APNSRequest(
            message: notification,
            deviceToken: deviceToken,
            pushType: .liveactivity,
            expiration: notification.expiration,
            priority: notification.priority,
            apnsID: notification.apnsID,
            topic: notification.topic,
            collapseID: nil
        )
        return try await send(request)
    }

    /// Sends a notification to start a live activity.
    ///
    /// - Parameters:
    ///   - notification: The notification to send.
    ///   - pushToStartToken: The hexadecimal bytes use to start a live on a device. Your app receives the bytes for this activity token
    ///    from the `pushToStartTokenUpdates` async stream on `Activity`.
    @discardableResult
    @inlinable
    public func sendStartLiveActivityNotification<Attributes: Encodable & Sendable, ContentState: Encodable & Sendable>(
        _ notification: APNSStartLiveActivityNotification<Attributes, ContentState>,
        pushToStartToken: String
    ) async throws -> APNSResponse {
        let request = APNSRequest(
            message: notification,
            deviceToken: pushToStartToken,
            pushType: .liveactivity,
            expiration: notification.expiration,
            priority: notification.priority,
            apnsID: notification.apnsID,
            topic: notification.topic,
            collapseID: nil
        )
        return try await send(request)
    }
}

