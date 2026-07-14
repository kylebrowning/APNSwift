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

/// The mechanism a Live Activity started via push uses to receive subsequent updates (iOS 18+).
public struct APNSLiveActivityInputPushMethod: Sendable, Hashable {
    internal enum Configuration: Sendable, Hashable {
        case token
        case channel(String)
    }
    internal var configuration: Configuration

    /// The device returns a fresh update push token for the started activity (`input-push-token: 1`).
    public static let token = Self(configuration: .token)

    /// The started activity receives updates from the given broadcast channel (`input-push-channel`).
    public static func channel(_ channelID: String) -> Self {
        Self(configuration: .channel(channelID))
    }
}
