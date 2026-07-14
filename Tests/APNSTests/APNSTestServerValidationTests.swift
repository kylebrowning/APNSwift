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

@testable import APNSCore
import APNS
import APNSTestServer
import Crypto
import XCTest
import NIOCore
import NIOHTTP1
import AsyncHTTPClient

/// Builds a fake (unsigned) provider authentication token in the shape the mock server expects:
/// `base64url(header).base64url(payload).base64url(signature)`. The server never verifies the
/// ES256 signature (it has no public key), so any bytes work there.
private func makeTestJWT(iss: String = "team", kid: String = "key", iatOffset: TimeInterval = 0) -> String {
    func base64url(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    let header = "{\"alg\":\"ES256\",\"typ\":\"JWT\",\"kid\":\"\(kid)\"}"
    let iat = Int(Date().timeIntervalSince1970 + iatOffset)
    let payload = "{\"iss\":\"\(iss)\",\"iat\":\(iat)}"

    return "\(base64url(header)).\(base64url(payload)).\(base64url("sig"))"
}

final class APNSTestServerValidationTests: XCTestCase {
    var server: APNSTestServer!
    var httpClient: HTTPClient!

    override func setUp() async throws {
        try await super.setUp()

        // Start the mock server
        server = APNSTestServer()
        try await server.start(port: 0)

        // Create raw HTTP client to test error cases
        httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    }

    override func tearDown() async throws {
        try await httpClient?.shutdown()
        try await server?.shutdown()
        try await super.tearDown()
    }

    // MARK: - BadDeviceToken Tests

    func testBadDeviceToken_tooShort() async throws {
        let response = try await sendRawNotification(
            deviceToken: "abc123",  // Only 6 chars, needs 64
            topic: "com.example.app",
            pushType: "alert"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadDeviceToken"))
    }

    func testBadDeviceToken_tooLong() async throws {
        let response = try await sendRawNotification(
            deviceToken: String(repeating: "a", count: 65),  // 65 chars, needs 64
            topic: "com.example.app",
            pushType: "alert"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadDeviceToken"))
    }

    func testBadDeviceToken_nonHexCharacters() async throws {
        let response = try await sendRawNotification(
            deviceToken: "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",  // 64 chars but not hex
            topic: "com.example.app",
            pushType: "alert"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadDeviceToken"))
    }

    func testBadDeviceToken_empty() async throws {
        let response = try await sendRawNotification(
            deviceToken: "",
            topic: "com.example.app",
            pushType: "alert"
        )

        // Empty device token results in /3/device/ which is MissingDeviceToken
        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("MissingDeviceToken"))
    }

    // MARK: - MissingTopic Tests

    func testMissingTopic() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: nil,  // Missing topic
            pushType: "alert"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("MissingTopic"))
    }

    // MARK: - InvalidPushType Tests

    func testInvalidPushType() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "invalid-type"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("InvalidPushType"))
    }

    func testInvalidPushType_empty() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: ""
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("InvalidPushType"))
    }

    // MARK: - BadPriority Tests

    func testBadPriority_invalidNumber() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            priority: "3"  // Invalid, must be 5 or 10
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadPriority"))
    }

    func testBadPriority_invalidString() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            priority: "high"  // Invalid, must be 5 or 10
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadPriority"))
    }

    // MARK: - BadExpirationDate Tests

    func testBadExpirationDate_nonNumeric() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            expiration: "not-a-number"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadExpirationDate"))
    }

    func testBadExpirationDate_float() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            expiration: "123.456"  // Should be integer
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadExpirationDate"))
    }

    // MARK: - BadCollapseId Tests

    func testBadCollapseId_tooLong() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            collapseID: String(repeating: "a", count: 65)  // Max is 64 bytes
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadCollapseId"))
    }

    func testBadCollapseId_exactly64Bytes() async throws {
        // This should PASS - exactly 64 bytes is valid
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            collapseID: String(repeating: "a", count: 64)
        )

        XCTAssertEqual(response.status, .ok)
    }

    // MARK: - PayloadEmpty Tests

    func testPayloadEmpty_noBody() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            body: nil  // No body
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("PayloadEmpty"))
    }

    func testPayloadEmpty_invalidJSON() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            body: "not valid json"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("PayloadEmpty"))
    }

    // MARK: - PayloadTooLarge Tests

    func testPayloadTooLarge() async throws {
        // Create a payload larger than 4096 bytes
        let largePayload = "{\"data\":\"" + String(repeating: "x", count: 5000) + "\"}"

        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            body: largePayload
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("PayloadTooLarge"))
    }

    func testPayloadExactly4096Bytes() async throws {
        // Create a payload exactly 4096 bytes - should PASS
        let exactSize = 4096 - "{\"data\":\"\"}".count
        let payload = "{\"data\":\"" + String(repeating: "x", count: exactSize) + "\"}"

        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            body: payload
        )

        XCTAssertEqual(response.status, .ok)
    }

    // MARK: - MissingDeviceToken Tests

    func testMissingDeviceToken() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device")
        request.method = .POST
        request.headers.add(name: "apns-topic", value: "com.example.app")
        request.headers.add(name: "apns-push-type", value: "alert")
        request.headers.add(name: "content-type", value: "application/json")
        request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")
        request.body = .bytes(ByteBuffer(string: "{}"))

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(bodyString.contains("MissingDeviceToken"))
    }

    // MARK: - MethodNotAllowed Tests

    func testMethodNotAllowed_GET() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        request.method = .GET
        request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        XCTAssertEqual(response.status, .methodNotAllowed)
        XCTAssertTrue(bodyString.contains("MethodNotAllowed"))
    }

    func testMethodNotAllowed_PUT() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        request.method = .PUT
        request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        XCTAssertEqual(response.status, .methodNotAllowed)
        XCTAssertTrue(bodyString.contains("MethodNotAllowed"))
    }

    func testMethodNotAllowed_DELETE() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        request.method = .DELETE
        request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        XCTAssertEqual(response.status, .methodNotAllowed)
        XCTAssertTrue(bodyString.contains("MethodNotAllowed"))
    }

    // MARK: - BadPath Tests

    func testBadPath_devices() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/devices/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        request.method = .POST
        request.headers.add(name: "apns-topic", value: "com.example.app")
        request.headers.add(name: "apns-push-type", value: "alert")
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(string: "{}"))

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        XCTAssertEqual(response.status, .notFound)
        XCTAssertTrue(bodyString.contains("BadPath"))
    }

    func testBadPath_wrongVersion() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/2/device/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        request.method = .POST
        request.headers.add(name: "apns-topic", value: "com.example.app")
        request.headers.add(name: "apns-push-type", value: "alert")
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(string: "{}"))

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        // Wrong version falls through to the generic bad-path case (not /3/...)
        XCTAssertEqual(response.status, .notFound)
        XCTAssertTrue(bodyString.contains("BadPath"))
    }

    // MARK: - Valid Push Types Test

    func testValidPushTypes() async throws {
        // Each push type that enforces a topic suffix must be sent with a matching topic.
        let topicByPushType: [String: String] = [
            "alert": "com.example.app",
            "background": "com.example.app",
            "location": "com.example.app.location-query",
            "voip": "com.example.app.voip",
            "complication": "com.example.app.complication",
            "fileprovider": "com.example.app.pushkit.fileprovider",
            "mdm": "com.example.app",
            "liveactivity": "com.example.app.push-type.liveactivity",
            "pushtotalk": "com.example.app.voip-ptt",
            "widgets": "com.example.app.push-type.widgets",
            "controls": "com.example.app.push-type.controls",
        ]

        for (pushType, topic) in topicByPushType {
            let response = try await sendRawNotification(
                deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
                topic: topic,
                pushType: pushType
            )

            XCTAssertEqual(response.status, .ok, "Push type '\(pushType)' should be valid, got: \(response.body)")
        }
    }

    // MARK: - Valid Priorities Test

    func testValidPriorities() async throws {
        for priority in ["1", "5", "10"] {
            let response = try await sendRawNotification(
                deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
                topic: "com.example.app",
                pushType: "alert",
                priority: priority
            )

            XCTAssertEqual(response.status, .ok, "Priority '\(priority)' should be valid")
        }

        // `background` pushes must pair with priority 5 — priority 10 is rejected (BadPriority).
        let backgroundResponse = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "background",
            priority: "5"
        )
        XCTAssertEqual(backgroundResponse.status, .ok)
    }

    // MARK: - Authorization Tests

    func testMissingAuthorization_returnsMissingProviderToken() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            authorization: nil
        )

        XCTAssertEqual(response.status, .forbidden)
        XCTAssertTrue(response.body.contains("MissingProviderToken"))
    }

    func testGarbageAuthorization_returnsInvalidProviderToken() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            authorization: "bearer not-a-real-token"
        )

        XCTAssertEqual(response.status, .forbidden)
        XCTAssertTrue(response.body.contains("InvalidProviderToken"))
    }

    func testStringIatToken_returnsInvalidProviderToken() async throws {
        // Pins the library-side fix: `iat` must be a JSON number, not a string (RFC 7519 NumericDate).
        func base64url(_ string: String) -> String {
            Data(string.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = base64url("{\"alg\":\"ES256\",\"typ\":\"JWT\",\"kid\":\"key\"}")
        let payload = base64url("{\"iss\":\"team\",\"iat\":\"\(Int(Date().timeIntervalSince1970))\"}")
        let token = "\(header).\(payload).\(base64url("sig"))"

        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            authorization: "bearer \(token)"
        )

        XCTAssertEqual(response.status, .forbidden)
        XCTAssertTrue(response.body.contains("InvalidProviderToken"))
    }

    func testExpiredIat_returnsExpiredProviderToken() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert",
            authorization: "bearer \(makeTestJWT(iatOffset: -3700))"
        )

        XCTAssertEqual(response.status, .forbidden)
        XCTAssertTrue(response.body.contains("ExpiredProviderToken"))
    }

    // MARK: - Topic Suffix Enforcement

    func testWrongTopicSuffix_voip_returnsBadTopic() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",  // missing the required `.voip` suffix
            pushType: "voip"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadTopic"))
    }

    // MARK: - Background Priority

    func testBackgroundWithPriority10_returnsBadPriority() async throws {
        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "background",
            priority: "10"
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("BadPriority"))
    }

    // MARK: - Per-Push-Type Payload Limits

    func testVoIPPayload_5000Bytes_accepted() async throws {
        let overhead = "{\"data\":\"\"}".utf8.count
        let payload = "{\"data\":\"" + String(repeating: "x", count: 5000 - overhead) + "\"}"
        XCTAssertEqual(payload.utf8.count, 5000)

        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app.voip",
            pushType: "voip",
            body: payload
        )

        XCTAssertEqual(response.status, .ok, "got: \(response.body)")
    }

    func testVoIPPayload_5200Bytes_rejected() async throws {
        let overhead = "{\"data\":\"\"}".utf8.count
        let payload = "{\"data\":\"" + String(repeating: "x", count: 5200 - overhead) + "\"}"
        XCTAssertEqual(payload.utf8.count, 5200)

        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app.voip",
            pushType: "voip",
            body: payload
        )

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(response.body.contains("PayloadTooLarge"))
    }

    // MARK: - Malformed apns-id

    func testMalformedAPNSID_returnsBadMessageId() async throws {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        request.method = .POST
        request.headers.add(name: "apns-topic", value: "com.example.app")
        request.headers.add(name: "apns-push-type", value: "alert")
        request.headers.add(name: "apns-id", value: "not-a-uuid")
        request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(string: "{}"))

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        XCTAssertEqual(response.status, .badRequest)
        XCTAssertTrue(bodyString.contains("BadMessageId"))
    }

    // MARK: - Response Override

    func testResponseOverride_forcesStatus() async throws {
        server.setResponseOverride(.init(status: 500, body: "{\"reason\":\"InternalServerError\"}"))

        let response = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert"
        )

        XCTAssertEqual(response.status, .internalServerError)
        XCTAssertTrue(response.body.contains("InternalServerError"))
        XCTAssertEqual(
            server.getSentNotifications().count, 0,
            "An overridden response must not be recorded as a sent notification"
        )

        // The override is consumed after a single use — the next request goes through normal handling.
        let secondResponse = try await sendRawNotification(
            deviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            topic: "com.example.app",
            pushType: "alert"
        )
        XCTAssertEqual(secondResponse.status, .ok)
    }

    // MARK: - Helper Methods

    private func sendRawNotification(
        deviceToken: String,
        topic: String?,
        pushType: String?,
        priority: String? = nil,
        expiration: String? = nil,
        collapseID: String? = nil,
        body: String? = "{}",
        authorization: String? = "bearer \(makeTestJWT())"
    ) async throws -> (status: HTTPResponseStatus, body: String) {
        var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/\(deviceToken)")
        request.method = .POST

        if let topic = topic {
            request.headers.add(name: "apns-topic", value: topic)
        }
        if let pushType = pushType {
            request.headers.add(name: "apns-push-type", value: pushType)
        }
        if let priority = priority {
            request.headers.add(name: "apns-priority", value: priority)
        }
        if let expiration = expiration {
            request.headers.add(name: "apns-expiration", value: expiration)
        }
        if let collapseID = collapseID {
            request.headers.add(name: "apns-collapse-id", value: collapseID)
        }
        if let authorization = authorization {
            request.headers.add(name: "authorization", value: authorization)
        }

        request.headers.add(name: "content-type", value: "application/json")

        if let body = body {
            request.body = .bytes(ByteBuffer(string: body))
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
        let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""

        return (response.status, bodyString)
    }
}
