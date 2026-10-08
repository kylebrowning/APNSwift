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
import struct FoundationEssentials.Date
#else
import struct Foundation.Date
#endif

public struct APNSLiveActivityDismissalDate: Hashable, Sendable {
    /// The date at which the live activity will be dismissed
    /// This value is a UNIX epoch expressed in seconds (UTC)
    @usableFromInline
    let dismissal: Int?

    /// Omits sending an dismissal date for APNs. APNs will default to a default value for dismissal time.
    public static let none = Self(dismissal: nil)

    /// Have live activity dismiss immediately when end received
    public static let immediately = Self(dismissal: 0)

    /// Specify dismissal as a unix time stamp, if in past will dismiss
    /// immedidately.
    public static func timeIntervalSince1970InSeconds(_ timeInterval: Int) -> Self {
        Self(dismissal: timeInterval)
    }
    
    /// Specify dismissal as a date, if in past will dismiss
    /// immedidately.
    public static func date(_ date: Date) -> Self {
        Self(dismissal: Int(date.timeIntervalSince1970))
    }
}
