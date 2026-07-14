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

struct APNSLiveActivityNotificationAPSStorage<ContentState: Encodable & Sendable>: Encodable {
    enum CodingKeys: String, CodingKey {
        case timestamp = "timestamp"
        case event = "event"
        case contentState = "content-state"
        case dismissalDate = "dismissal-date"
        case staleDate = "stale-date"
        case alert = "alert"
        case relevanceScore = "relevance-score"
    }

    var timestamp: Int
    var event: String
    var contentState: ContentState
    var dismissalDate: Int?
    var staleDate: Int?
    var alert: APNSAlertNotificationContent?
    var relevanceScore: Double?

    init(
        timestamp: Int,
        event: String,
        contentState: ContentState,
        dismissalDate: Int?,
        staleDate: Int?,
        alert: APNSAlertNotificationContent? = nil,
        relevanceScore: Double? = nil
    ) {
        self.timestamp = timestamp
        self.contentState = contentState
        self.dismissalDate = dismissalDate
        self.staleDate = staleDate
        self.event = event
        self.alert = alert
        self.relevanceScore = relevanceScore
    }
}
