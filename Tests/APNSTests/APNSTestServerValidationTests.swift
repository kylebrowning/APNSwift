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
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1
import Testing

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

private let validToken = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

private func sendRawNotification(
    server: APNSTestServer,
    httpClient: HTTPClient,
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

    return try await execute(request, with: httpClient)
}

private func execute(
    _ request: HTTPClientRequest,
    with httpClient: HTTPClient
) async throws -> (status: HTTPResponseStatus, body: String) {
    let response = try await httpClient.execute(request, timeout: .seconds(30))
    let bodyBuffer = try await response.body.collect(upTo: 1024 * 1024)
    let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) ?? ""
    return (response.status, bodyString)
}

struct APNSTestServerValidationTests {

    // MARK: - BadDeviceToken Tests

    @Test(arguments: [
        "abc123",  // Only 6 chars, needs 64
        String(repeating: "a", count: 65),  // 65 chars, needs 64
        "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",  // 64 chars but not hex
    ])
    func `Bad device token is rejected`(deviceToken: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: deviceToken,
                topic: "com.example.app",
                pushType: "alert"
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadDeviceToken"))
        }
    }

    @Test func `Bad device token empty`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: "",
                topic: "com.example.app",
                pushType: "alert"
            )

            // Empty device token results in /3/device/ which is MissingDeviceToken
            #expect(response.status == .badRequest)
            #expect(response.body.contains("MissingDeviceToken"))
        }
    }

    // MARK: - MissingTopic Tests

    @Test func missingTopic() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: nil,  // Missing topic
                pushType: "alert"
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("MissingTopic"))
        }
    }

    // MARK: - InvalidPushType Tests

    @Test(arguments: ["invalid-type", ""])
    func `Invalid push type is rejected`(pushType: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: pushType
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("InvalidPushType"))
        }
    }

    // MARK: - BadPriority Tests

    @Test(arguments: [
        "3",  // Invalid, must be 5 or 10
        "high",  // Invalid, must be 5 or 10
    ])
    func `Bad priority is rejected`(priority: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                priority: priority
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadPriority"))
        }
    }

    // MARK: - BadExpirationDate Tests

    @Test(arguments: [
        "not-a-number",
        "123.456",  // Should be integer
    ])
    func `Bad expiration date is rejected`(expiration: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                expiration: expiration
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadExpirationDate"))
        }
    }

    // MARK: - BadCollapseId Tests

    @Test func `Bad collapse id too long`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                collapseID: String(repeating: "a", count: 65)  // Max is 64 bytes
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadCollapseId"))
        }
    }

    @Test func `Collapse id exactly 64 bytes is accepted`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            // This should PASS - exactly 64 bytes is valid
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                collapseID: String(repeating: "a", count: 64)
            )

            #expect(response.status == .ok)
        }
    }

    // MARK: - PayloadEmpty Tests

    @Test(arguments: [
        nil,  // No body
        "not valid json",
    ] as [String?])
    func `Empty or invalid payload is rejected`(body: String?) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                body: body
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("PayloadEmpty"))
        }
    }

    // MARK: - PayloadTooLarge Tests

    @Test func payloadTooLarge() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            // Create a payload larger than 4096 bytes
            let largePayload = "{\"data\":\"" + String(repeating: "x", count: 5000) + "\"}"

            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                body: largePayload
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("PayloadTooLarge"))
        }
    }

    @Test func `Payload exactly 4096 bytes is accepted`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            // Create a payload exactly 4096 bytes - should PASS
            let exactSize = 4096 - "{\"data\":\"\"}".count
            let payload = "{\"data\":\"" + String(repeating: "x", count: exactSize) + "\"}"

            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                body: payload
            )

            #expect(response.status == .ok)
        }
    }

    // MARK: - MissingDeviceToken Tests

    @Test func missingDeviceToken() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device")
            request.method = .POST
            request.headers.add(name: "apns-topic", value: "com.example.app")
            request.headers.add(name: "apns-push-type", value: "alert")
            request.headers.add(name: "content-type", value: "application/json")
            request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")
            request.body = .bytes(ByteBuffer(string: "{}"))

            let response = try await execute(request, with: httpClient)

            #expect(response.status == .badRequest)
            #expect(response.body.contains("MissingDeviceToken"))
        }
    }

    // MARK: - MethodNotAllowed Tests

    @Test(arguments: [HTTPMethod.GET, .PUT, .DELETE])
    func `Method not allowed`(method: HTTPMethod) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/\(validToken)")
            request.method = method
            request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")

            let response = try await execute(request, with: httpClient)

            #expect(response.status == .methodNotAllowed)
            #expect(response.body.contains("MethodNotAllowed"))
        }
    }

    // MARK: - BadPath Tests

    @Test(arguments: [
        "/3/devices/\(validToken)",
        // Wrong version falls through to the generic bad-path case (not /3/...)
        "/2/device/\(validToken)",
    ])
    func `Bad path is rejected`(path: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)\(path)")
            request.method = .POST
            request.headers.add(name: "apns-topic", value: "com.example.app")
            request.headers.add(name: "apns-push-type", value: "alert")
            request.headers.add(name: "content-type", value: "application/json")
            request.body = .bytes(ByteBuffer(string: "{}"))

            let response = try await execute(request, with: httpClient)

            #expect(response.status == .notFound)
            #expect(response.body.contains("BadPath"))
        }
    }

    // MARK: - Valid Push Types Test

    @Test(arguments: [
        ("alert", "com.example.app"),
        ("background", "com.example.app"),
        ("location", "com.example.app.location-query"),
        ("voip", "com.example.app.voip"),
        ("complication", "com.example.app.complication"),
        ("fileprovider", "com.example.app.pushkit.fileprovider"),
        ("mdm", "com.example.app"),
        ("liveactivity", "com.example.app.push-type.liveactivity"),
        ("pushtotalk", "com.example.app.voip-ptt"),
        ("widgets", "com.example.app.push-type.widgets"),
        ("controls", "com.example.app.push-type.controls"),
        ("accessory", "com.example.app.push-type.accessory"),
    ])
    func `Valid push type is accepted`(pushType: String, topic: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: topic,
                pushType: pushType
            )

            #expect(response.status == .ok, "Push type '\(pushType)' should be valid, got: \(response.body)")
        }
    }

    // MARK: - Valid Priorities Test

    @Test(arguments: ["1", "5", "10"])
    func `Valid priority is accepted`(priority: String) async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                priority: priority
            )

            #expect(response.status == .ok, "Priority '\(priority)' should be valid")
        }
    }

    @Test func `Background with priority 5 is accepted`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "background",
                priority: "5"
            )

            #expect(response.status == .ok)
        }
    }

    // MARK: - Authorization Tests

    @Test func `Missing authorization returns MissingProviderToken`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                authorization: nil
            )

            #expect(response.status == .forbidden)
            #expect(response.body.contains("MissingProviderToken"))
        }
    }

    @Test func `Garbage authorization returns InvalidProviderToken`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                authorization: "bearer not-a-real-token"
            )

            #expect(response.status == .forbidden)
            #expect(response.body.contains("InvalidProviderToken"))
        }
    }

    @Test func `String iat token returns InvalidProviderToken`() async throws {
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

        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                authorization: "bearer \(token)"
            )

            #expect(response.status == .forbidden)
            #expect(response.body.contains("InvalidProviderToken"))
        }
    }

    @Test func `Expired iat returns ExpiredProviderToken`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert",
                authorization: "bearer \(makeTestJWT(iatOffset: -3700))"
            )

            #expect(response.status == .forbidden)
            #expect(response.body.contains("ExpiredProviderToken"))
        }
    }

    // MARK: - Topic Suffix Enforcement

    @Test func `Wrong topic suffix for voip returns BadTopic`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",  // missing the required `.voip` suffix
                pushType: "voip"
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadTopic"))
        }
    }

    // MARK: - Background Priority

    @Test func `Background with priority 10 returns BadPriority`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "background",
                priority: "10"
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadPriority"))
        }
    }

    // MARK: - Per-Push-Type Payload Limits

    @Test func `VoIP payload of 5000 bytes is accepted`() async throws {
        let overhead = "{\"data\":\"\"}".utf8.count
        let payload = "{\"data\":\"" + String(repeating: "x", count: 5000 - overhead) + "\"}"
        #expect(payload.utf8.count == 5000)

        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app.voip",
                pushType: "voip",
                body: payload
            )

            #expect(response.status == .ok, "got: \(response.body)")
        }
    }

    @Test func `VoIP payload of 5200 bytes is rejected`() async throws {
        let overhead = "{\"data\":\"\"}".utf8.count
        let payload = "{\"data\":\"" + String(repeating: "x", count: 5200 - overhead) + "\"}"
        #expect(payload.utf8.count == 5200)

        try await TestFixtures.withRawHTTPClient { server, httpClient in
            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app.voip",
                pushType: "voip",
                body: payload
            )

            #expect(response.status == .badRequest)
            #expect(response.body.contains("PayloadTooLarge"))
        }
    }

    // MARK: - Malformed apns-id

    @Test func `Malformed apns-id returns BadMessageId`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            var request = HTTPClientRequest(url: "http://127.0.0.1:\(server.port)/3/device/\(validToken)")
            request.method = .POST
            request.headers.add(name: "apns-topic", value: "com.example.app")
            request.headers.add(name: "apns-push-type", value: "alert")
            request.headers.add(name: "apns-id", value: "not-a-uuid")
            request.headers.add(name: "authorization", value: "bearer \(makeTestJWT())")
            request.headers.add(name: "content-type", value: "application/json")
            request.body = .bytes(ByteBuffer(string: "{}"))

            let response = try await execute(request, with: httpClient)

            #expect(response.status == .badRequest)
            #expect(response.body.contains("BadMessageId"))
        }
    }

    // MARK: - Response Override

    @Test func `Response override forces status`() async throws {
        try await TestFixtures.withRawHTTPClient { server, httpClient in
            server.setResponseOverride(.init(status: 500, body: "{\"reason\":\"InternalServerError\"}"))

            let response = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert"
            )

            #expect(response.status == .internalServerError)
            #expect(response.body.contains("InternalServerError"))
            #expect(
                server.getSentNotifications().count == 0,
                "An overridden response must not be recorded as a sent notification"
            )

            // The override is consumed after a single use — the next request goes through normal handling.
            let secondResponse = try await sendRawNotification(
                server: server,
                httpClient: httpClient,
                deviceToken: validToken,
                topic: "com.example.app",
                pushType: "alert"
            )
            #expect(secondResponse.status == .ok)
        }
    }
}
