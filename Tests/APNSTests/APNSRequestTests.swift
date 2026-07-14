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

private struct TestMessage: APNSMessage {}

/// Direct coverage of ``APNSCore.APNSRequest.headers``, which is the URLSession client's
/// entire header contract.
final class APNSRequestTests: XCTestCase {
    func testHeaders_fullRequestEmitsAllHeaders() throws {
        let apnsID = UUID()
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            pushType: .alert,
            expiration: .timeIntervalSince1970InSeconds(1_234_567_890),
            priority: .immediately,
            apnsID: apnsID,
            topic: "com.example.app",
            collapseID: "collapse-123"
        )

        let headers = request.headers

        XCTAssertEqual(headers["apns-id"], apnsID.uuidString.lowercased())
        XCTAssertEqual(headers["apns-expiration"], "1234567890")
        XCTAssertEqual(headers["apns-priority"], "10")
        XCTAssertEqual(headers["apns-topic"], "com.example.app")
        XCTAssertEqual(headers["apns-collapse-id"], "collapse-123")
        XCTAssertEqual(headers["apns-push-type"], "alert")
    }

    func testHeaders_apnsIDIsLowercased() throws {
        // UUID() can produce uppercase hex; the header value must always be lowercased.
        let apnsID = UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890")!
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: nil,
            priority: nil,
            apnsID: apnsID,
            topic: nil,
            collapseID: nil
        )

        XCTAssertEqual(request.headers["apns-id"], "abcdef12-3456-7890-abcd-ef1234567890")
    }

    func testHeaders_minimalRequestOmitsOptionalHeaders() throws {
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .background,
            expiration: nil,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        let headers = request.headers

        XCTAssertEqual(headers["apns-push-type"], "background")
        XCTAssertNil(headers["apns-id"])
        XCTAssertNil(headers["apns-expiration"])
        XCTAssertNil(headers["apns-priority"])
        XCTAssertNil(headers["apns-topic"])
        XCTAssertNil(headers["apns-collapse-id"])
    }

    func testHeaders_expirationImmediatelyIsZero() throws {
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: .immediately,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        XCTAssertEqual(request.headers["apns-expiration"], "0")
    }

    func testHeaders_expirationNoneOmitsHeader() throws {
        // `APNSNotificationExpiration.none` (as opposed to a `nil` `APNSRequest.expiration`)
        // must also omit the header.
        let noneExpiration: APNSNotificationExpiration? = APNSNotificationExpiration.none
        let request = APNSRequest(
            message: TestMessage(),
            deviceToken: "token",
            pushType: .alert,
            expiration: noneExpiration,
            priority: nil,
            apnsID: nil,
            topic: nil,
            collapseID: nil
        )

        XCTAssertNil(request.headers["apns-expiration"])
    }
}
