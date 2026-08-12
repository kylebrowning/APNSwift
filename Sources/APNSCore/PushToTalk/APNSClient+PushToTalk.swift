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
    /// Sends a Push To Talk (PTT) notification to APNs.
    ///
    /// - Parameters:
    ///   - notification: The notification to send.
    ///
    ///   - deviceToken: The hexadecimal bytes that identify the user’s device. Your app receives the bytes for this device token
    ///    when registering for remote notifications.
    ///
    @discardableResult
    @inlinable
    public func sendPushToTalkNotification<Payload: Encodable & Sendable>(
        _ notification: APNSPushToTalkNotification<Payload>,
        deviceToken: String
    ) async throws -> APNSResponse {
        let request = APNSRequest(
            message: notification,
            deviceToken: deviceToken,
            pushType: .pushtotalk,
            expiration: notification.expiration,
            priority: notification.priority,
            apnsID: notification.apnsID,
            topic: notification.topic,
            collapseID: nil
        )
        return try await send(request)
    }
}
