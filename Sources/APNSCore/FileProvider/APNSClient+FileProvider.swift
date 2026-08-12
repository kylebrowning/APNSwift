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
    /// Sends a file provider notification to APNs.
    ///
    /// - Parameters:
    ///   - notification: The notification to send.
    ///
    ///   - deviceToken: The hexadecimal bytes that identify the user’s device. Your app receives the bytes for this device token
    ///    when registering for remote notifications.
    ///
    @discardableResult
    @inlinable
    public func sendFileProviderNotification<Payload: Encodable & Sendable>(
        _ notification: APNSFileProviderNotification<Payload>,
        deviceToken: String
    ) async throws -> APNSResponse {
        let request = APNSRequest(
            message: notification,
            deviceToken: deviceToken,
            pushType: .fileprovider,
            expiration: notification.expiration,
            // This always needs to be consideringDevicePower otherwise APNs returns an error
            priority: .consideringDevicePower,
            apnsID: notification.apnsID,
            topic: notification.topic,
            collapseID: nil
        )
        return try await send(request)
    }
}
