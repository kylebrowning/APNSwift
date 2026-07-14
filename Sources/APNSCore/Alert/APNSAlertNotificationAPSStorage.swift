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

struct APNSAlertNotificationAPSStorage: Encodable, Sendable {
    enum CodingKeys: String, CodingKey {
        case alert
        case badge
        case sound
        case threadID = "thread-id"
        case category
        case mutableContent = "mutable-content"
        case targetContentID = "target-content-id"
        case interruptionLevel = "interruption-level"
        case relevanceScore = "relevance-score"
        case filterCriteria = "filter-criteria"
    }

    var alert: APNSAlertNotificationContent

    var badge: Int?

    var sound: APNSAlertNotificationSound?

    var threadID: String?

    var category: String?

    var mutableContent: Double?

    var targetContentID: String?

    var interruptionLevel: APNSAlertNotificationInterruptionLevel?

    var relevanceScore: Double? {
        willSet {
            if let newValue = newValue {
                precondition(newValue >= 0 && newValue <= 1, "The relevance score can only be between 0 and 1")
            }
        }
    }

    var filterCriteria: String?

    init(
        alert: APNSAlertNotificationContent,
        badge: Int? = nil,
        sound: APNSAlertNotificationSound? = nil,
        threadID: String? = nil,
        category: String? = nil,
        mutableContent: Double? = nil,
        targetContentID: String? = nil,
        interruptionLevel: APNSAlertNotificationInterruptionLevel? = nil,
        relevanceScore: Double? = nil,
        filterCriteria: String? = nil
    ) {
        if let relevanceScore = relevanceScore {
            precondition(relevanceScore >= 0 && relevanceScore <= 1, "The relevance score can only be between 0 and 1")
        }
        self.alert = alert
        self.badge = badge
        self.sound = sound
        self.threadID = threadID
        self.category = category
        self.mutableContent = mutableContent
        self.targetContentID = targetContentID
        self.interruptionLevel = interruptionLevel
        self.relevanceScore = relevanceScore
        self.filterCriteria = filterCriteria
    }
}
