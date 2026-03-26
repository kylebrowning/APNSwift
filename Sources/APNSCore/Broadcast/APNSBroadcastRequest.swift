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

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// Represents a request to the APNs broadcast channel management API.
public struct APNSBroadcastRequest<Message: Encodable>: Sendable where Message: Sendable {
    /// The type of broadcast operation to perform.
    public enum Operation: Sendable {
        /// Create a new broadcast channel.
        case create
        /// Read an existing broadcast channel.
        case read(channelID: String)
        /// Delete an existing broadcast channel.
        case delete(channelID: String)
        /// List all broadcast channels.
        case listAll

        /// The HTTP method as a string.
        public var httpMethod: String {
            switch self {
            case .create:
                return "POST"
            case .read, .listAll:
                return "GET"
            case .delete:
                return "DELETE"
            }
        }

        /// The path for this operation.
        public var path: String {
            switch self {
            case .create, .delete, .read, .listAll:
                return "/channels"
            }
        }

        /// HTTP Headers for this operation.
        public var headers: [String: String]? {
            switch self {
            case .delete(let channelID), .read(channelID: let channelID):
                return ["apns-channel-id": channelID]
            default:
                return nil
            }
        }
    }

    /// The operation to perform.
    public let operation: Operation

    /// The message payload for operations that require a body (e.g., create).
    public let message: Message?

    /// An optional request ID for tracking.
    public let apnsRequestID: UUID?

    /// Creates a broadcast request.
    ///
    /// - Parameters:
    ///   - operation: The type of operation to perform.
    ///   - message: The message payload (required for create operations).
    ///   - apnsRequestID: An optional request ID for tracking.
    public init(
        operation: Operation,
        message: Message? = nil,
        apnsRequestID: UUID? = nil
    ) {
        self.operation = operation
        self.message = message
        self.apnsRequestID = apnsRequestID
    }
}
