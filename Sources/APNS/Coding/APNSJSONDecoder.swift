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

/// A protocol that is similar to the `JSONDecoder`. This allows users of APNSwift to customize the decoder used
/// for decoding the APNS response bodies.
public protocol APNSJSONDecoder {
    func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T
}

extension JSONDecoder: APNSJSONDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        var copy = buffer
        let data = copy.readData(length: buffer.readableBytes)!
        return try self.decode(type, from: data)
    }
}
