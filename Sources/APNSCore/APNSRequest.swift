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

/// A request to send a single ``APNSMessage`` to a device.
public struct APNSRequest<Message: APNSMessage>: Sendable {
    /// The message to send.
    public var message: Message

    /// The hexadecimal bytes that identify the user's device.
    public var deviceToken: String

    /// The value of the `apns-push-type` header.
    public var pushType: APNSPushType

    /// The value of the `apns-expiration` header, if any.
    public var expiration: APNSNotificationExpiration?

    /// The value of the `apns-priority` header, if any.
    public var priority: APNSPriority?

    /// The value of the `apns-id` header, if any.
    public var apnsID: UUID?

    /// The value of the `apns-topic` header, if any.
    public var topic: String?

    /// The value of the `apns-collapse-id` header, if any.
    public var collapseID: String?

    /// The `apns-*` headers derived from this request. This is the single source of truth
    /// for header derivation and is used by every client implementation.
    public var headers: [String: String] {
        var computedHeaders: [String: String] = [:]

        computedHeaders["apns-push-type"] = pushType.configuration.rawValue

        if let apnsID = apnsID {
            computedHeaders["apns-id"] = apnsID.uuidString.lowercased()
        }

        if let expiration = expiration?.expiration {
            computedHeaders["apns-expiration"] = "\(expiration)"
        }

        if let priority = priority?.rawValue {
            computedHeaders["apns-priority"] = "\(priority)"
        }

        if let topic = topic {
            computedHeaders["apns-topic"] = topic
        }

        if let collapseID = collapseID {
            computedHeaders["apns-collapse-id"] = collapseID
        }

        return computedHeaders
    }

    public init(
        message: Message,
        deviceToken: String,
        pushType: APNSPushType,
        expiration: APNSNotificationExpiration?,
        priority: APNSPriority?,
        apnsID: UUID?,
        topic: String?,
        collapseID: String?
    ) {
        self.message = message
        self.deviceToken = deviceToken
        self.pushType = pushType
        self.expiration = expiration
        self.priority = priority
        self.apnsID = apnsID
        self.topic = topic
        self.collapseID = collapseID
    }
}
