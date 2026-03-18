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
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOFoundationCompat

/// A protocol that is similar to the `JSONEncoder`. This allows users of APNSwift to customize the encoder used
/// for encoding the notification JSON payloads.
public protocol APNSJSONEncoder {
    func encode<T: Encodable>(_ value: T, into buffer: inout ByteBuffer) throws
}

extension JSONEncoder: APNSJSONEncoder {
    public func encode<T: Encodable>(_ value: T, into buffer: inout ByteBuffer) throws {
        let data = try encode(value)
        buffer.writeData(data)
    }
}
