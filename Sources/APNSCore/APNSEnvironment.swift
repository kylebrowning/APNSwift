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

/// The APNs environment.
public struct APNSEnvironment: Sendable {
    /// The production APNs environment.
    public static let production = Self(url: "https://api.push.apple.com", port: 443)

    /// The sandbox APNs environment.
    @available(*, deprecated, renamed: "development")
    public static let sandbox = development
    
    /// The development APNs environment.
    public static let development = Self(url: "https://api.development.push.apple.com", port: 443)

    /// Creates an APNs environment with a custom URL.
    ///
    /// - Note: This is mostly used for testing purposes.
    public static func custom(url: String, port: Int = 443) -> Self {
        Self(url: url, port: port)
    }

    /// The environment's URL.
    public let url: String
    
    /// The environment's port.
    public let port: Int
    
    /// The fully constructed URL.
    public var absoluteURL: String {
        "\(url):\(port)/3/device"
    }

    /// The fully constructed URL for publishing a broadcast push notification.
    ///
    /// Broadcast pushes are sent to the regular device-push host, not the channel-management host.
    ///
    /// - Parameter bundleID: The app's bundle identifier.
    public func broadcastSendURL(bundleID: String) -> String {
        "\(url):\(port)/4/broadcasts/apps/\(bundleID)"
    }
}
