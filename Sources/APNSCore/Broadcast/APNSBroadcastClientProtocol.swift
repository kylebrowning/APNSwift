//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2024 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.UUID

/// Protocol defining the broadcast channel management operations.
public protocol APNSBroadcastClientProtocol: Sendable {
    /// Sends a broadcast channel management request.
    ///
    /// - Parameter request: The broadcast request to send.
    /// - Returns: A response containing the result.
    func send<Message: Encodable & Sendable, ResponseBody: Decodable & Sendable>(
        _ request: APNSBroadcastRequest<Message>
    ) async throws -> APNSBroadcastResponse<ResponseBody>
}

extension APNSBroadcastClientProtocol {
    /// Creates a new broadcast channel.
    ///
    /// - Parameters:
    ///   - channel: The channel configuration.
    ///   - apnsRequestID: An optional request ID for tracking.
    /// - Returns: The created channel information.
    public func create(
        channel: APNSBroadcastChannel,
        apnsRequestID: UUID? = nil
    ) async throws -> APNSBroadcastResponse<EmptyPayload> {
        let request = APNSBroadcastRequest<APNSBroadcastChannel>(
            operation: .create,
            message: channel,
            apnsRequestID: apnsRequestID
        )
        return try await send(request)
    }

    /// Reads information about an existing broadcast channel.
    ///
    /// - Parameters:
    ///   - channelID: The ID of the channel to read.
    ///   - apnsRequestID: An optional request ID for tracking.
    /// - Returns: The channel information.
    public func read(
        channelID: String,
        apnsRequestID: UUID? = nil
    ) async throws -> APNSBroadcastResponse<APNSBroadcastChannel> {
        let request = APNSBroadcastRequest<EmptyPayload>(
            operation: .read(channelID: channelID),
            message: nil,
            apnsRequestID: apnsRequestID
        )
        return try await send(request)
    }

    /// Deletes an existing broadcast channel.
    ///
    /// - Parameters:
    ///   - channelID: The ID of the channel to delete.
    ///   - apnsRequestID: An optional request ID for tracking.
    /// - Returns: An empty response.
    public func delete(
        channelID: String,
        apnsRequestID: UUID? = nil
    ) async throws -> APNSBroadcastResponse<EmptyPayload> {
        let request = APNSBroadcastRequest<EmptyPayload>(
            operation: .delete(channelID: channelID),
            message: nil,
            apnsRequestID: apnsRequestID
        )
        return try await send(request)
    }

    /// Lists all broadcast channel IDs.
    ///
    /// - Parameter apnsRequestID: An optional request ID for tracking.
    /// - Returns: A list of all channel IDs.
    public func readAllChannelIDs(
        apnsRequestID: UUID? = nil
    ) async throws -> APNSBroadcastResponse<APNSBroadcastChannelList> {
        let request = APNSBroadcastRequest<EmptyPayload>(
            operation: .listAll,
            message: nil,
            apnsRequestID: apnsRequestID
        )
        return try await send(request)
    }
}
