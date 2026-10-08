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
import APNS
import APNSTestServer
import Foundation
import Testing

/// Exercises the NIO-based ``APNSClient``'s error-handling path against forced server responses,
/// via ``APNSTestServer/setResponseOverride(_:)``. These pin the behaviour that an undecodable
/// error body (empty, non-JSON, or oversized) must still surface as a typed `APNSError` with
/// `reason: nil`, rather than a raw `DecodingError`/`NIOTooManyBytesError`.
struct APNSClientErrorPathTests {

    @Test(arguments: [
        (UInt(500), String?.none),
        (UInt(503), "<html>unavailable</html>"),
        (UInt(400), String(repeating: "x", count: 2048)),
    ])
    func `Undecodable error body yields typed error with nil reason`(status: UInt, body: String?) async throws {
        try await TestFixtures.withClient { server, client in
            server.setResponseOverride(.init(status: status, body: body))

            let error = try await #require(throws: APNSError.self) {
                try await client.sendAlertNotification(Self.makeAlert(), deviceToken: TestFixtures.validDeviceToken)
            }
            #expect(error.responseStatus == Int(status))
            #expect(error.reason == nil)
        }
    }

    @Test(arguments: [
        (UInt(429), #"{"reason":"TooManyRequests"}"#, APNSError.ErrorReason.tooManyRequests),
        (UInt(400), #"{"reason":"ChannelNotRegistered"}"#, APNSError.ErrorReason.channelNotRegistered),
    ])
    func `Decodable error body yields typed error with reason`(
        status: UInt,
        body: String,
        reason: APNSError.ErrorReason
    ) async throws {
        try await TestFixtures.withClient { server, client in
            server.setResponseOverride(.init(status: status, body: body))

            let error = try await #require(throws: APNSError.self) {
                try await client.sendAlertNotification(Self.makeAlert(), deviceToken: TestFixtures.validDeviceToken)
            }
            #expect(error.responseStatus == Int(status))
            #expect(error.reason == reason)
        }
    }

    // MARK: - Helpers

    private static func makeAlert() -> APNSAlertNotification<EmptyPayload> {
        APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.example.app",
            payload: EmptyPayload()
        )
    }
}
