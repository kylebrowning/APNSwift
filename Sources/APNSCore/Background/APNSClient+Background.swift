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
    /// Sends a background update notification to APNs.
    ///
    /// - Parameters:
    ///   - notification: The notification to send.
    ///
    ///   - deviceToken: The hexadecimal bytes that identify the user’s device. Your app receives the bytes for this device token
    ///    when registering for remote notifications.
    ///
    @discardableResult
    @inlinable
    public func sendBackgroundNotification<Payload: Encodable & Sendable>(
        _ notification: APNSBackgroundNotification<Payload>,
        deviceToken: String
    ) async throws -> APNSResponse {
        let request = APNSRequest(
            message: notification,
            deviceToken: deviceToken,
            pushType: .background,
            expiration: notification.expiration,
            priority: .consideringDevicePower,
            apnsID: notification.apnsID,
            topic: notification.topic,
            collapseID: nil
        )
        return try await send(request)
    }
}
