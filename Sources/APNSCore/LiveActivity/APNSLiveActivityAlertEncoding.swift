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

/// Encodes an ``APNSAlertNotificationContent`` in the shape ActivityKit expects for Live Activity alerts.
///
/// Regular notifications use flat localization keys (`title-loc-key`, `loc-key`, ...). Live Activity
/// alerts instead nest the localization under each field:
///
/// ```json
/// "alert": {
///   "title": { "loc-key": "...", "loc-args": [] },
///   "body":  { "loc-key": "...", "loc-args": [] },
///   "sound": "chime.aiff"
/// }
/// ```
///
/// iOS silently discards Live Activity pushes whose alert uses the flat keys.
struct APNSLiveActivityAlertEncoding: Encodable {
    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case body
        case launchImage = "launch-image"
        case sound
    }

    private struct LocalizedString: Encodable {
        enum CodingKeys: String, CodingKey {
            case key = "loc-key"
            case arguments = "loc-args"
        }

        var key: String
        var arguments: [String]
    }

    var content: APNSAlertNotificationContent

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try self.encode(self.content.title, into: &container, forKey: .title)
        try self.encode(self.content.subtitle, into: &container, forKey: .subtitle)
        try self.encode(self.content.body, into: &container, forKey: .body)
        try container.encodeIfPresent(self.content.launchImage, forKey: .launchImage)
        try container.encodeIfPresent(self.content.sound, forKey: .sound)
    }

    private func encode(
        _ value: APNSAlertNotificationContent.StringValue?,
        into container: inout KeyedEncodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws {
        switch value?.configuration {
        case .raw(let value):
            try container.encode(value, forKey: key)
        case .localized(let localizationKey, let arguments):
            try container.encode(LocalizedString(key: localizationKey, arguments: arguments), forKey: key)
        case .none:
            break
        }
    }
}
