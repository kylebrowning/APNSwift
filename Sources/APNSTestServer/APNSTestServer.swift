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
import struct Foundation.UUID
import struct Foundation.Data
import class Foundation.JSONSerialization
import class Foundation.JSONDecoder
import struct Foundation.CharacterSet

/// A comprehensive mock server that simulates Apple Push Notification service APIs.
///
/// This server supports both:
/// - **Regular push notifications**: `POST /3/device/{token}`
/// - **Broadcast channels**: `POST/GET/DELETE /channels[/{id}]`
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
    private var broadcastChannels: [String: MockBroadcastChannel] = [:]
    private var sentNotifications: [SentNotification] = []

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
        return sentNotifications
    }

    /// Clears all sent notifications.
    public func clearSentNotifications() {
        sentNotifications.removeAll()
    }

    fileprivate func handleRequest(
        method: HTTPMethod,
        uri: String,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        // Parse the URI
        let components = uri.split(separator: "/")

        // Broadcast channel endpoints: /1/apps/{bundleID}/channels
        // Channel ID is passed via apns-channel-id header for read/delete operations
        switch (method, components.count) {
        case (.POST, 4) where components[0] == "1" && components[1] == "apps" && components[3] == "channels":
            return handleCreateChannel(body: body)

        case (.GET, 4) where components[0] == "1" && components[1] == "apps" && components[3] == "channels":
            if let channelID = headers.first(name: "apns-channel-id") {
                return handleReadChannel(channelID: channelID)
            }
            return handleListChannels()

        case (.DELETE, 4) where components[0] == "1" && components[1] == "apps" && components[3] == "channels":
            guard let channelID = headers.first(name: "apns-channel-id") else {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"MissingChannelID\"}")
            }
            return handleDeleteChannel(channelID: channelID)

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
            return (.notFound, responseHeaders, "{\"reason\":\"NotFound\"}")
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
        broadcastChannels[channelID] = channel

        var headers = HTTPHeaders()
        headers.add(name: "apns-channel-id", value: channelID)
        return (.ok, headers, "")
    }

    private func handleListChannels() -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        let channelIDs = Array(broadcastChannels.keys)
        let channelsJSON = channelIDs.map { "\"\($0)\"" }.joined(separator: ",")

        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")

        return (.ok, headers, "{\"channels\":[\(channelsJSON)]}")
    }

    private func handleReadChannel(channelID: String) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")

        guard let channel = broadcastChannels[channelID] else {
            return (.notFound, headers, "{\"reason\":\"NotFound\"}")
        }

        let responseJSON = """
        {"message-storage-policy":\(channel.messageStoragePolicy),"push-type":"\(channel.pushType)"}
        """
        return (.ok, headers, responseJSON)
    }

    private func handleDeleteChannel(channelID: String) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        var headers = HTTPHeaders()

        guard broadcastChannels.removeValue(forKey: channelID) != nil else {
            headers.add(name: "content-type", value: "application/json")
            return (.notFound, headers, "{\"reason\":\"NotFound\"}")
        }

        return (.noContent, headers, "")
    }

    // MARK: - Push Notification Handler

    private func handlePushNotification(
        deviceToken: String,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> (status: HTTPResponseStatus, headers: HTTPHeaders, body: String) {
        // Validate device token (Apple requires exactly 64 hexadecimal characters)
        let isValidHex = deviceToken.count == 64 && deviceToken.allSatisfy { $0.isHexDigit }
        if !isValidHex {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"BadDeviceToken\"}")
        }

        // Validate required topic header
        guard headers.contains(name: "apns-topic") else {
            var responseHeaders = HTTPHeaders()
            responseHeaders.add(name: "content-type", value: "application/json")
            return (.badRequest, responseHeaders, "{\"reason\":\"MissingTopic\"}")
        }

        // Validate push type if present
        if let pushType = headers.first(name: "apns-push-type") {
            let validPushTypes = ["alert", "background", "location", "voip", "complication",
                                  "fileprovider", "mdm", "liveactivity", "pushtotalk", "widgets"]
            if !validPushTypes.contains(pushType) {
                var responseHeaders = HTTPHeaders()
                responseHeaders.add(name: "content-type", value: "application/json")
                return (.badRequest, responseHeaders, "{\"reason\":\"InvalidPushType\"}")
            }
        }

        // Validate priority if present
        if let priority = headers.first(name: "apns-priority") {
            if priority != "5" && priority != "10" {
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

        // Validate payload size (Apple's limit is 4KB for most notifications)
        if payload.count > 4096 {
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

        // Extract headers
        let pushType = headers.first(name: "apns-push-type")
        let topic = headers.first(name: "apns-topic")
        let priority = headers.first(name: "apns-priority")
        let expiration = headers.first(name: "apns-expiration")
        let collapseID = headers.first(name: "apns-collapse-id")
        let apnsID = headers.first(name: "apns-id").flatMap { UUID(uuidString: $0) } ?? UUID()

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
        sentNotifications.append(notification)

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
            if !finalHeaders.contains(name: "apns-request-id") {
                finalHeaders.add(name: "apns-request-id", value: UUID().uuidString)
            }
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
