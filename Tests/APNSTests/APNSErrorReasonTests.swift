//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2024 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import APNSCore
import XCTest

final class APNSErrorReasonTests: XCTestCase {
    /// Every known APNs reason string paired with the case it must map to.
    private static let knownReasons: [(APNSError.ErrorReason.Reason, String)] = [
        (.badCollapseIdentifier, "BadCollapseId"),
        (.badDeviceToken, "BadDeviceToken"),
        (.badExpirationDate, "BadExpirationDate"),
        (.badMessageId, "BadMessageId"),
        (.badPriority, "BadPriority"),
        (.badTopic, "BadTopic"),
        (.deviceTokenNotForTopic, "DeviceTokenNotForTopic"),
        (.duplicateHeaders, "DuplicateHeaders"),
        (.idleTimeout, "IdleTimeout"),
        (.invalidPushType, "InvalidPushType"),
        (.missingDeviceToken, "MissingDeviceToken"),
        (.missingTopic, "MissingTopic"),
        (.payloadEmpty, "PayloadEmpty"),
        (.topicDisallowed, "TopicDisallowed"),
        (.badCertificate, "BadCertificate"),
        (.badCertificateEnvironment, "BadCertificateEnvironment"),
        (.expiredProviderToken, "ExpiredProviderToken"),
        (.forbidden, "Forbidden"),
        (.invalidProviderToken, "InvalidProviderToken"),
        (.missingProviderToken, "MissingProviderToken"),
        (.unrelatedKeyIdInToken, "UnrelatedKeyIdInToken"),
        (.badEnvironmentKeyIdInToken, "BadEnvironmentKeyIdInToken"),
        (.badPath, "BadPath"),
        (.methodNotAllowed, "MethodNotAllowed"),
        (.expiredToken, "ExpiredToken"),
        (.unregistered, "Unregistered"),
        (.payloadTooLarge, "PayloadTooLarge"),
        (.tooManyProviderTokenUpdates, "TooManyProviderTokenUpdates"),
        (.tooManyRequests, "TooManyRequests"),
        (.internalServerError, "InternalServerError"),
        (.serviceUnavailable, "ServiceUnavailable"),
        (.shutdown, "Shutdown"),
        (.badEnvironmentKeyInToken, "BadEnvironmentKeyInToken"),
    ]

    func testEveryKnownReasonRoundTrips() {
        for (reason, raw) in Self.knownReasons {
            XCTAssertEqual(reason.rawValue, raw, "rawValue mismatch for \(reason)")
            XCTAssertEqual(
                APNSError.ErrorReason.Reason(rawValue: raw),
                reason,
                "string \"\(raw)\" did not map back to \(reason)"
            )
            XCTAssertFalse(reason.errorDescription.isEmpty, "missing description for \(reason)")
        }
    }

    func testUnknownReasonIsPreserved() {
        let reason = APNSError.ErrorReason.Reason(rawValue: "SomeBrandNewReason")
        XCTAssertEqual(reason, .unknown("SomeBrandNewReason"))
        XCTAssertEqual(reason.rawValue, "SomeBrandNewReason")
        XCTAssertFalse(reason.errorDescription.isEmpty)
    }

    /// `BadEnvironmentKeyInToken` and `BadEnvironmentKeyIdInToken` differ by a single `Id` —
    /// guard against the two being conflated.
    func testSimilarEnvironmentReasonsAreDistinct() {
        XCTAssertNotEqual(
            APNSError.ErrorReason.Reason.badEnvironmentKeyInToken,
            APNSError.ErrorReason.Reason.badEnvironmentKeyIdInToken
        )
        XCTAssertEqual(
            APNSError.ErrorReason.Reason(rawValue: "BadEnvironmentKeyInToken"),
            .badEnvironmentKeyInToken
        )
        XCTAssertEqual(
            APNSError.ErrorReason.Reason(rawValue: "BadEnvironmentKeyIdInToken"),
            .badEnvironmentKeyIdInToken
        )
    }

    /// Exercises the path `APNSError` actually uses: decoding an `APNSErrorResponse` and
    /// surfacing the typed reason.
    func testErrorMapsDecodedResponseReason() throws {
        let data = Data(#"{"reason":"BadDeviceToken"}"#.utf8)
        let response = try JSONDecoder().decode(APNSErrorResponse.self, from: data)
        let error = APNSError(responseStatus: 400, apnsResponse: response)
        XCTAssertEqual(error.reason, .badDeviceToken)
    }
}
