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

/// A struct which represents the supported priorities by APNs.
public struct APNSPriority: Hashable, Encodable, Sendable {
    /// The underlying raw value that is send to APNs.
    public let rawValue: Int

    /// Specifies that the notification should be send immediately.
    public static let immediately = Self(rawValue: 10)

    /// Specifies that the notification should be send based on power considerations on the user’s device.
    public static let consideringDevicePower = Self(rawValue: 5)

    /// Specifies that the notification should be sent in a way that prioritizes the device’s power
    /// considerations over all other factors, and prevents awakening the device.
    public static let prioritizeDevicePower = Self(rawValue: 1)
}
