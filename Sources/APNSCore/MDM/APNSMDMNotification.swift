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

public struct APNSMDMNotification: APNSMessage {
    @usableFromInline
    enum CodingKeys: String, CodingKey {
        case pushMagic = "mdm"
    }

    public var pushMagic: String

    public var apnsID: UUID?

    public var topic: String

    @inlinable
    public init(
        topic: String,
        pushMagic: String,
        apnsID: UUID? = nil
    ) {
        self.topic = topic
        self.pushMagic = pushMagic
        self.apnsID = apnsID
    }

    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.pushMagic, forKey: .pushMagic)
    }
}
