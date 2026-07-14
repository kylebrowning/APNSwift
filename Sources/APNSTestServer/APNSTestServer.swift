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

import NIOCore
import NIOPosix
import NIOHTTP1
import NIOConcurrencyHelpers
import struct Foundation.UUID
import struct Foundation.Data
import struct Foundation.Date
import class Foundation.JSONSerialization
import class Foundation.JSONDecoder
import class Foundation.NSNumber
import struct Foundation.CharacterSet

/// A comprehensive mock server that simulates Apple Push Notification service APIs.
///
/// This server supports:
/// - **Regular push notifications**: `POST /3/device/{token}`
/// - **Broadcast channels**: `POST/GET/DELETE /1/apps/{bundleID}/channels` (+ `GET /1/apps/{bundleID}/all-channels`)
/// - **Broadcast send**: `POST /4/broadcasts/apps/{bundleID}`
///
/// ## Usage
///
/// ```swift
/// let server = APNSTestServer()
/// try await server.start(port: 0)
///
/// // Use server.port to configure your APNS clients
/// let client = APNSClient(
///     configuration: .init(
///         authenticationMethod: .jwt(...),
///         environment: .custom(url: "http://127.0.0.1", port: server.port)
///     ),
///     ...
/// )
///
/// // Cleanup
/// try await server.shutdown()
/// ```
public final class APNSTestServer: @unchecked Sendable {
    private let group: EventLoopGroup
    private var channel: Channel?
    private let broadcastChannelsBox = NIOLockedValueBox<[String: MockBroadcastChannel]>([:])
    private let sentNotificationsBox = NIOLockedValueBox<[SentNotification]>([])
    private let broadcastRequestsBox = NIOLockedValueBox<[BroadcastRequestRecord]>([])
    private let broadcastSendsBox = NIOLockedValueBox<[BroadcastSendRecord]>([])
    private let responseOverrideBox = NIOLockedValueBox<ResponseOverride?>(nil)

    public var port: Int {
        guard let channel = channel else {
            return 0
        }
        return channel.localAddress?.port ?? 0
    }

    /// Represents a notification that was sent to the server.
    public struct SentNotification {
        public let deviceToken: String
        public let pushType: String?
        public let topic: String?
        public let priority: String?
        public let expiration: String?
        public let collapseID: String?
        public let apnsID: UUID
        public let payload: Data

        public func decodedPayload<T: Decodable>(as type: T.Type) throws -> T {
            try JSONDecoder().decode(type, from: payload)
        }
    }

    /// Metadata captured about a request made to a broadcast/channel management endpoint,
    /// so tests can assert what the client actually sent (independent of what the server decided to do with it).
    public struct BroadcastRequestRecord: Sendable {
        /// The raw request URI, e.g. `/1/apps/com.example.app/channels`.
        public let path: String
        /// The HTTP method, e.g. `"POST"`, `"GET"`, `"DELETE"`.
        public let method: String
        /// The `apns-request-id` header the client sent, if any.
        public let apnsRequestID: String?
        /// The `apns-channel-id` header the client sent, if any.
        public let apnsChannelID: String?
    }

    /// Metadata captured about a broadcast push notification sent to
    /// `POST /4/broadcasts/apps/{bundleID}`.
    public struct BroadcastSendRecord: Sendable {
        /// The app's bundle identifier the broadcast was sent to.
        public let bundleID: String
        /// The `apns-channel-id` header the client sent.
        public let channelID: String
        /// The `apns-request-id` header the client sent, if any.
        public let receivedRequestID: String?
        /// The `apns-push-type` header the client sent.
        public let pushType: String
        /// The `apns-expiration` header the client sent.
        public let expiration: String
        /// The `apns-priority` header the client sent.
        public let priority: String
        /// The raw JSON payload the client sent.
        public let payload: Data

        public func decodedPayload<T: Decodable>(as type: T.Type) throws -> T {
            try JSONDecoder().decode(type, from: payload)
        }
    }

    /// A forced response for the *next* `/3/device/{token}` request, letting tests simulate
    /// server-side failures (500/503/429) or malformed bodies without the mock server's usual validation.
    public struct ResponseOverride: Sendable {
        /// The HTTP status code to respond with.
        public var status: UInt
        /// The raw response body. Defaults to an empty body.
        public var body: String?
        /// Additional response headers.
        public var headers: [(String, String)]

        public init(status: UInt, body: String? = nil, headers: [(String, String)] = []) {
            self.status = status
            self.body = body
            self.headers = headers
        }
    }

    struct MockBroadcastChannel: Codable {
        let channelID: String
        let messageStoragePolicy: Int
        let pushType: String

        enum CodingKeys: String, CodingKey {
            case channelID = "channel-id"
            case messageStoragePolicy = "message-storage-policy"
            case pushType = "push-type"
        }
    }

    /// A valid-hex device token that the server treats as unregistered, responding with `410 Unregistered`.
    public static let unregisteredDeviceToken = String(repeating: "f", count: 64)

    /// The `timestamp` (milliseconds since epoch) returned alongside a simulated `410 Unregistered` response.
    public static let unregisteredTimestampMilliseconds = 1_454_096_879_000

    /// Push types that require the `apns-topic` header to end with a specific suffix.
    private static let topicSuffixRequirements: [String: String] = [
        "voip": ".voip",
        "pushtotalk": ".voip-ptt",
        "complication": ".complication",
        "fileprovider": ".pushkit.fileprovider",
        "liveactivity": ".push-type.liveactivity",
        "location": ".location-query",
        "widgets": ".push-type.widgets",
        "controls": ".push-type.controls",
    ]

    private static let validPushTypes: Set<String> = [
        "alert", "background", "location", "voip", "complication",
        "fileprovider", "mdm", "liveactivity", "pushtotalk", "widgets", "controls",
    ]

    public init() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    /// Starts the server on the specified port.
    ///
    /// - Parameter port: The port to bind to. Use 0 for a random available port.
    public func start(port: Int = 0) async throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                do {
                    try channel.pipeline.syncOperations.configureHTTPServerPipeline()
                    try channel.pipeline.syncOperations.addHandler(APNSRequestHandler(server: self))
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }

        self.channel = try await bootstrap.bind(host: "127.0.0.1", port: port).get()
    }

    /// Stops the server.
    public func shutdown() async throws {
        try await channel?.close()
        try await group.shutdownGracefully()
    }

    /// Returns all notifications sent to this server.
    public func getSentNotifications() -> [SentNotification] {
        sentNotificationsBox.withLockedValue { $0 }
    }

    /// Clears all sent notifications.
    public func clearSentNotifications() {
        sentNotificationsBox.withLockedValue { $0.removeAll() }
    }

    /// Returns all requests made to broadcast/channel management endpoints.
    public func getBroadcastRequests() -> [BroadcastRequestRecord] {
        broadcastRequestsBox.withLockedValue { $0 }
    }

    /// Returns all broadcast push notifications sent to `POST /4/broadcasts/apps/{bundleID}`.
    public func getBroadcastSends() -> [BroadcastSendRecord] {
        broadcastSendsBox.withLockedValue { $0 }
    }

    /// Forces the *next* `/3/device/{token}` response to be exactly `override`, bypassing all normal
    /// validation. The override is consumed (cleared) after a single use. Pass `nil` to clear it without use.
    public func setResponseOverride(_ override: ResponseOverride?) {
        responseOverrideBox.withLockedValue { $0 = override }
    }

    private func takeResponseOverride() -> ResponseOverride? {
        responseOverrideBox.withLockedValue { value in
            defer { value = nil }
            return value
        }
    }

    // MARK: - Authorization

    private struct AuthFailure {
        let status: HTTPResponseStatus
        let reason: String
    }

    /// Restores base64url padding and decodes to `Data`. The server never verifies the ES256
    /// signature (it has no public key) — it only validates structure and claims.
    private static func base64URLDecode(_ segment: Substring) -> Data? {
        var characters = Array(segment)
        for index in characters.indices {
            if characters[index] == "-" {
                characters[index] = "+"
            } else if characters[index] == "_" {
                characters[index] = "/"
            }
        }
        var base64 = String(characters)
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    /// Validates the `authorization` header of a device-push or broadcast/channel request.
    ///
    /// Order matches Apple's own precedence: missing/malformed scheme first, then structural/claim
    /// issues, then expiry. The ES256 signature itself is never checked.
    private static func validateAuthorization(headers: HTTPHeaders) -> AuthFailure? {
        guard let authHeader = headers.first(name: "authorization") else {
            return AuthFailure(status: .forbidden, reason: "MissingProviderToken")
        }

        let schemeAndToken = authHeader.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard schemeAndToken.count == 2, schemeAndToken[0].lowercased() == "bearer" else {
            return AuthFailure(status: .forbidden, reason: "MissingProviderToken")
        }

        let token = schemeAndToken[1]
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            return AuthFailure(status: .forbidden, reason: "InvalidProviderToken")
        }

        guard let headerData = base64URLDecode(segments[0]),
              let headerJSON = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              let alg = headerJSON["alg"] as? String, alg == "ES256",
              headerJSON["kid"] != nil
        else {
            return AuthFailure(status: .forbidden, reason: "InvalidProviderToken")
        }

        guard let payloadData = base64URLDecode(segments[1]),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              payloadJSON["iss"] != nil
        else {
            return AuthFailure(status: .forbidden, reason: "InvalidProviderToken")
        }

        // A string `iat` (e.g. the pre-fix library bug) must be rejected as invalid, not merely expired.
        guard let iatNumber = payloadJSON["iat"] as? NSNumber else {
            return AuthFailure(status: .forbidden, reason: "InvalidProviderToken")
        }

        let iatSeconds = iatNumber.doubleValue
        let nowSeconds = Date().timeIntervalSince1970
        if nowSeconds - iatSeconds > 3600 {
            return AuthFailure(status: .forbidden, reason: "ExpiredProviderToken")
        }

        return nil
    }

    // MARK: - Request dispatch

    fileprivate func handleRequest(
        method: HTTPMethod,
        uri: String,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        // Parse the URI
        let components = uri.split(separator: "/")

        let isAppsPath = components.count >= 2 && components[0] == "1" && components[1] == "apps"
        let isDevicePushAttempt = components.count >= 2 && components[0] == "3" && components[1] == "device"
        let isBroadcastSendAttempt = components.count >= 2 && components[0] == "4" && components[1] == "broadcasts"

        if isAppsPath {
            recordBroadcastRequest(uri: uri, method: method, headers: headers)
        }

        // Authorization is validated before all other request validation on device-push,
        // broadcast/channel, and broadcast-send endpoints.
        if isAppsPath || isDevicePushAttempt || isBroadcastSendAttempt {
            if let failure = Self.validateAuthorization(headers: headers) {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                let result = (failure.status, responseHeaders, "{\"reason\":\"\(failure.reason)\"}")
                return finalize(
                    result,
                    isDevicePush: isDevicePushAttempt,
                    isBroadcast: isAppsPath,
                    isBroadcastSend: isBroadcastSendAttempt,
                    requestHeaders: headers
                )
            }
        }

        let result = dispatch(method: method, components: components, headers: headers, body: body)
        return finalize(
            result,
            isDevicePush: isDevicePushAttempt,
            isBroadcast: isAppsPath,
            isBroadcastSend: isBroadcastSendAttempt,
            requestHeaders: headers
        )
    }

    /// Adds the response headers that are consistent across an entire path family
    /// (`apns-unique-id` for device pushes, `apns-request-id` for broadcast/channel operations,
    /// and both `apns-request-id`/`apns-unique-id` for broadcast-send).
    private func finalize(
        _ result: (status: HTTPResponseStatus, headers: HTTPHeaders, body: String),
        isDevicePush: Bool,
        isBroadcast: Bool,
        isBroadcastSend: Bool,
        requestHeaders: HTTPHeaders
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        var responseHeaders = result.headers

        if (isDevicePush || isBroadcastSend) && !responseHeaders.contains(name: "apns-unique-id") {
            responseHeaders.add(name: "apns-unique-id", value: UUID().uuidString)
        }

        if (isBroadcast || isBroadcastSend) && !responseHeaders.contains(name: "apns-request-id") {
            let requestID = requestHeaders.first(name: "apns-request-id") ?? UUID().uuidString
            responseHeaders.add(name: "apns-request-id", value: requestID)
        }

        return (result.status, responseHeaders, result.body)
    }

    private func recordBroadcastRequest(uri: String, method: HTTPMethod, headers: HTTPHeaders) {
        let record = BroadcastRequestRecord(
            path: uri,
            method: String(describing: method),
            apnsRequestID: headers.first(name: "apns-request-id"),
            apnsChannelID: headers.first(name: "apns-channel-id")
        )
        broadcastRequestsBox.withLockedValue { $0.append(record) }
    }

    private func dispatch(
        method: HTTPMethod,
        components: [Substring],
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        let isAppsPath = components.count >= 2 && components[0] == "1" && components[1] == "apps"
        let isChannelsPath = isAppsPath && components.count == 4 && components[3] == "channels"
        let isAllChannelsPath = isAppsPath && components.count == 4 && components[3] == "all-channels"

        // Broadcast channel endpoints: /1/apps/{bundleID}/channels
        // Channel ID is passed via apns-channel-id header for read/delete operations
        if isChannelsPath {
            switch method {
            case .POST:
                return handleCreateChannel(body: body)

            case .GET:
                // Reading a single channel requires the channel ID header. Unlike the real
                // APNs API, `GET .../channels` without an ID is NOT the list endpoint
                // (that lives at `.../all-channels`), so reject it rather than silently listing.
                guard let channelID = headers.first(name: "apns-channel-id") else {
                    var responseHeaders = HTTPHeaders()
                    responseHeaders.add(name: "content-type", value: "application/json")
                    return (.badRequest, responseHeaders, "{\"reason\":\"MissingChannelId\"}")
                }
                return handleReadChannel(channelID: channelID)

            case .DELETE:
                guard let channelID = headers.first(name: "apns-channel-id") else {
                    var responseHeaders = HTTPHeaders()
                    responseHeaders.add(name: "content-type", value: "application/json")
                    return (.badRequest, responseHeaders, "{\"reason\":\"MissingChannelId\"}")
                }
                return handleDeleteChannel(channelID: channelID)

            default:
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.methodNotAllowed, responseHeaders, "{\"reason\":\"MethodNotAllowed\"}")
            }
        }

        if isAllChannelsPath {
            switch method {
            case .GET:
                return handleListChannels()
            default:
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.methodNotAllowed, responseHeaders, "{\"reason\":\"MethodNotAllowed\"}")
            }
        }

        // Broadcast send endpoint: POST /4/broadcasts/apps/{bundleID}
        let isBroadcastSendPath = components.count >= 3
            && components[0] == "4" && components[1] == "broadcasts" && components[2] == "apps"

        if isBroadcastSendPath {
            guard components.count == 4 else {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.notFound, responseHeaders, "{\"reason\":\"BadPath\"}")
            }

            let bundleID = String(components[3])

            switch method {
            case .POST:
                return handleBroadcastSend(bundleID: bundleID, headers: headers, body: body)
            default:
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.methodNotAllowed, responseHeaders, "{\"reason\":\"MethodNotAllowed\"}")
            }
        }

        switch (method, components.count) {
        // Regular push notification endpoint: POST /3/device/{token}
        case (.POST, 3) where components[0] == "3" && components[1] == "device":
            let deviceToken = String(components[2])
            return handlePushNotification(deviceToken: deviceToken, headers: headers, body: body)

        // Handle POST /3/device with missing token
        case (.POST, 2) where components[0] == "3" && components[1] == "device":
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"MissingDeviceToken\"}")

        // Handle wrong HTTP method for /3/device/{token}
        case (_, 3) where components[0] == "3" && components[1] == "device":
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.methodNotAllowed, responseHeaders, "{\"reason\":\"MethodNotAllowed\"}")

        // Handle bad path (e.g., /3/devices instead of /3/device)
        case (.POST, _) where components.count >= 1 && components[0] == "3":
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.notFound, responseHeaders, "{\"reason\":\"BadPath\"}")

        default:
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.notFound, responseHeaders, "{\"reason\":\"BadPath\"}")
        }
    }

    // MARK: - Broadcast Channel Handlers

    private func handleCreateChannel(body: ByteBuffer?) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        guard var body = body else {
            var headers = HTTPHeaders()
            headers.add(name: "content-type", value: "application/json")
            return (.badRequest, headers, "{\"reason\":\"BadRequest\"}")
        }

        guard let bytes = body.readBytes(length: body.readableBytes) else {
            var headers = HTTPHeaders()
            headers.add(name: "content-type", value: "application/json")
            return (.badRequest, headers, "{\"reason\":\"BadRequest\"}")
        }

        let data = Data(bytes)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let policy = json["message-storage-policy"] as? Int,
              let pushType = json["push-type"] as? String else {
            var headers = HTTPHeaders()
            headers.add(name: "content-type", value: "application/json")
            return (.badRequest, headers, "{\"reason\":\"BadRequest\"}")
        }

        let channelID = UUID().uuidString
        let channel = MockBroadcastChannel(channelID: channelID, messageStoragePolicy: policy, pushType: pushType)
        broadcastChannelsBox.withLockedValue { $0[channelID] = channel }

        var headers = HTTPHeaders()
        headers.add(name: "apns-channel-id", value: channelID)
        return (.created, headers, "")
    }

    private func handleListChannels() -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        let channelIDs = broadcastChannelsBox.withLockedValue { Array($0.keys) }
        let channelsJSON = channelIDs.map { "\"\($0)\"" }.joined(separator: ",")

        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")

        return (.ok, headers, "{\"channels\":[\(channelsJSON)]}")
    }

    private func handleReadChannel(channelID: String) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")

        guard let channel = broadcastChannelsBox.withLockedValue({ $0[channelID] }) else {
            return (.badRequest, headers, "{\"reason\":\"ChannelNotRegistered\"}")
        }

        let responseJSON = """
        {"message-storage-policy":\(channel.messageStoragePolicy),"push-type":"\(channel.pushType)"}
        """
        return (.ok, headers, responseJSON)
    }

    private func handleDeleteChannel(channelID: String) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        var headers = HTTPHeaders()

        guard broadcastChannelsBox.withLockedValue({ $0.removeValue(forKey: channelID) }) != nil else {
            headers.add(name: "content-type", value: "application/json")
            return (.badRequest, headers, "{\"reason\":\"ChannelNotRegistered\"}")
        }

        return (.noContent, headers, "")
    }

    // MARK: - Broadcast Send Handler

    /// Handles `POST /4/broadcasts/apps/{bundleID}`, i.e. publishing a broadcast push.
    ///
    /// Unlike channel management (`/1/apps/...`), broadcast sends live on the regular device-push
    /// host and are validated similarly to `/3/device/{token}`, but against broadcast-specific rules.
    /// See: https://developer.apple.com/documentation/usernotifications/sending-broadcast-push-notification-requests-to-apns
    private func handleBroadcastSend(
        bundleID: String,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        func badRequest(_ reason: String) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"\(reason)\"}")
        }

        guard let channelID = headers.first(name: "apns-channel-id") else {
            return badRequest("MissingChannelId")
        }

        guard let pushType = headers.first(name: "apns-push-type") else {
            return badRequest("MissingPushType")
        }

        // Broadcast only supports Live Activity updates/ends; it cannot start an activity.
        guard pushType == "liveactivity" else {
            return badRequest("InvalidPushType")
        }

        guard let expiration = headers.first(name: "apns-expiration"), Int(expiration) != nil else {
            return badRequest("BadExpirationDate")
        }

        guard let priority = headers.first(name: "apns-priority"),
              priority == "1" || priority == "5" || priority == "10"
        else {
            return badRequest("BadPriority")
        }

        let channelIsRegistered = broadcastChannelsBox.withLockedValue { $0[channelID] != nil }
        guard channelIsRegistered else {
            return badRequest("ChannelNotRegistered")
        }

        guard var bodyBuffer = body,
              let bytes = bodyBuffer.readBytes(length: bodyBuffer.readableBytes),
              !bytes.isEmpty
        else {
            return badRequest("PayloadEmpty")
        }

        let payload = Data(bytes)

        guard (try? JSONSerialization.jsonObject(with: payload)) != nil else {
            return badRequest("PayloadEmpty")
        }

        if payload.count > 5120 {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.payloadTooLarge, responseHeaders, "{\"reason\":\"PayloadTooLarge\"}")
        }

        let record = BroadcastSendRecord(
            bundleID: bundleID,
            channelID: channelID,
            receivedRequestID: headers.first(name: "apns-request-id"),
            pushType: pushType,
            expiration: expiration,
            priority: priority,
            payload: payload
        )
        broadcastSendsBox.withLockedValue { $0.append(record) }

        var responseHeaders = HTTPHeaders()
        responseHeaders.add(name: "content-type", value: "application/json")
        return (.ok, responseHeaders, "{}")
    }

    // MARK: - Push Notification Handler

    private func handlePushNotification(
        deviceToken: String,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        // A test-forced response bypasses all normal validation and isn't recorded as a sent notification.
        if let override = takeResponseOverride() {
            var responseHeaders = HTTPHeaders()
            for (name, value) in override.headers {
                responseHeaders.add(name: name, value: value)
            }
            if !responseHeaders.contains(name: "content-type") {
                responseHeaders.add(name: "content-type", value: "application/json")
            }
            return (HTTPResponseStatus(statusCode: Int(override.status)), responseHeaders, override.body ?? "")
        }

        // Validate device token (Apple requires exactly 64 hexadecimal characters)
        let isValidHex = deviceToken.count == 64 && deviceToken.allSatisfy { $0.isHexDigit }
        if !isValidHex {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"BadDeviceToken\"}")
        }

        // Simulate an unregistered token: a valid-hex token equal to `Self.unregisteredDeviceToken`
        // responds with `410 Unregistered` and a `timestamp`, mirroring Apple's behaviour so the
        // `APNSError.timestamp` decoding path can be exercised.
        if deviceToken == Self.unregisteredDeviceToken {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.gone, responseHeaders, "{\"reason\":\"Unregistered\",\"timestamp\":\(Self.unregisteredTimestampMilliseconds)}")
        }

        // Validate required topic header
        guard let topic = headers.first(name: "apns-topic") else {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"MissingTopic\"}")
        }

        // Validate apns-id if present: malformed values are rejected outright rather than silently
        // replaced, matching Apple's `BadMessageId`.
        var apnsID = UUID()
        if let apnsIDHeader = headers.first(name: "apns-id") {
            guard let parsedID = UUID(uuidString: apnsIDHeader) else {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"BadMessageId\"}")
            }
            apnsID = parsedID
        }

        // Validate push type if present
        let pushType = headers.first(name: "apns-push-type")
        if let pushType = pushType {
            guard Self.validPushTypes.contains(pushType) else {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"InvalidPushType\"}")
            }

            if let requiredSuffix = Self.topicSuffixRequirements[pushType], !topic.hasSuffix(requiredSuffix) {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"BadTopic\"}")
            }
        }

        // Validate priority if present
        if let priority = headers.first(name: "apns-priority") {
            guard priority == "1" || priority == "5" || priority == "10" else {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"BadPriority\"}")
            }

            // Apple rejects `background` pushes sent with immediate (10) priority.
            if priority == "10" && pushType == "background" {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"BadPriority\"}")
            }
        }

        // Validate expiration if present (must be valid Unix timestamp or 0)
        if let expiration = headers.first(name: "apns-expiration") {
            if Int(expiration) == nil {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"BadExpirationDate\"}")
            }
        }

        // Validate collapse-id if present (max 64 bytes)
        if let collapseID = headers.first(name: "apns-collapse-id") {
            if collapseID.utf8.count > 64 {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"BadCollapseId\"}")
            }
        }

        // Validate payload exists
        guard var body = body else {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"PayloadEmpty\"}")
        }

        guard let bytes = body.readBytes(length: body.readableBytes) else {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"PayloadEmpty\"}")
        }

        let payload = Data(bytes)

        // Validate payload size. Apple's limit is 4KB for most notifications, but VoIP pushes get 5KB.
        let payloadLimit = pushType == "voip" ? 5120 : 4096
        if payload.count > payloadLimit {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"PayloadTooLarge\"}")
        }

        // Validate that it's valid JSON
        guard (try? JSONSerialization.jsonObject(with: payload)) != nil else {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"PayloadEmpty\"}")
        }

        // Extract remaining headers
        let priority = headers.first(name: "apns-priority")
        let expiration = headers.first(name: "apns-expiration")
        let collapseID = headers.first(name: "apns-collapse-id")

        // Store the notification
        let notification = SentNotification(
            deviceToken: deviceToken,
            pushType: pushType,
            topic: topic,
            priority: priority,
            expiration: expiration,
            collapseID: collapseID,
            apnsID: apnsID,
            payload: payload
        )
        sentNotificationsBox.withLockedValue { $0.append(notification) }

        // Return success
        var responseHeaders = HTTPHeaders()
        responseHeaders.add(name: "content-type", value: "application/json")
        responseHeaders.add(name: "apns-id", value: apnsID.uuidString.lowercased())

        return (.ok, responseHeaders, "{}")
    }
}

private final class APNSRequestHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let server: APNSTestServer
    private var method: HTTPMethod?
    private var uri: String?
    private var headers: HTTPHeaders?
    private var bodyBuffer: ByteBuffer?

    init(server: APNSTestServer) {
        self.server = server
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            self.method = head.method
            self.uri = head.uri
            self.headers = head.headers
            self.bodyBuffer = nil

        case .body(var buffer):
            if self.bodyBuffer == nil {
                self.bodyBuffer = buffer
            } else {
                self.bodyBuffer?.writeBuffer(&buffer)
            }

        case .end:
            guard let method = self.method,
                  let uri = self.uri,
                  let headers = self.headers else {
                return
            }

            let (status, responseHeaders, body) = server.handleRequest(
                method: method,
                uri: uri,
                headers: headers,
                body: bodyBuffer
            )

            var finalHeaders = responseHeaders
            finalHeaders.add(name: "content-length", value: String(body.utf8.count))

            let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: finalHeaders)
            context.write(wrapOutboundOut(.head(responseHead)), promise: nil)

            var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
            buffer.writeString(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)

            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)

            self.method = nil
            self.uri = nil
            self.headers = nil
            self.bodyBuffer = nil
        }
    }
}
