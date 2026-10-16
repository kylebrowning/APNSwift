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

public struct APNSAccessoryNotification: APNSMessage {
    @usableFromInline
    struct APS: Encodable, Sendable {
        let encryptedData: String
        let sessionIdentifier: String
        let keyID: String
        let messageIndex: String

        @usableFromInline
        init(encryptedData: String, sessionIdentifier: String, keyID: String, messageIndex: String) {
            self.encryptedData = encryptedData
            self.sessionIdentifier = sessionIdentifier
            self.keyID = keyID
            self.messageIndex = messageIndex
        }
    }

    @usableFromInline
    enum CodingKeys: CodingKey {
        case aps
    }

    @usableFromInline
    internal let aps: APS

    public var encryptedData: String {
        self.aps.encryptedData
    }

    public var sessionIdentifier: String {
        self.aps.sessionIdentifier
    }

    public var keyID: String {
        self.aps.keyID
    }

    public var messageIndex: UInt64? {
        UInt64(self.aps.messageIndex)
    }

    public var apnsID: UUID?

    public var topic: String

    @inlinable
    public init(
        appID: String,
        encryptedData: String,
        sessionIdentifier: String,
        keyID: String,
        messageIndex: UInt64,
        apnsID: UUID? = nil
    ) {
        self.init(
            topic: appID + ".push-type.accessory",
            encryptedData: encryptedData,
            sessionIdentifier: sessionIdentifier,
            keyID: keyID,
            messageIndex: messageIndex,
            apnsID: apnsID
        )
    }

    @inlinable
    public init(
        topic: String,
        encryptedData: String,
        sessionIdentifier: String,
        keyID: String,
        messageIndex: UInt64,
        apnsID: UUID? = nil
    ) {
        self.aps = APS(
            encryptedData: encryptedData,
            sessionIdentifier: sessionIdentifier,
            keyID: keyID,
            messageIndex: String(messageIndex)
        )
        self.topic = topic
        self.apnsID = apnsID
    }
}
