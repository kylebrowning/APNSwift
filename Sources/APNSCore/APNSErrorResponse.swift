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

/// A struct for the error response of APNs.
///
/// This decodes the JSON body APNs returns alongside a non-success status code.
public struct APNSErrorResponse: Codable, Sendable {
    /// The error code indicating the reason for the failure.
    public var reason: String

    /// The time, represented in milliseconds since Epoch, at which APNs confirmed the token was no longer valid for the topic.
    /// This key is included only when the error in the `:status` field is `410`.
    public var timestamp: Int?

    /// The time, represented in seconds since Epoch, at which APNs confirmed the token was no longer valid for the topic.
    public var timestampInSeconds: Double? {
        self.timestamp.flatMap { Double($0) / 1000 }
    }
}
