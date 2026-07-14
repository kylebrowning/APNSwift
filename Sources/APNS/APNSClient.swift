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

import APNSCore
import AsyncHTTPClient
#if canImport(FoundationEssentials)
import struct FoundationEssentials.Date
import struct FoundationEssentials.UUID
#else
import struct Foundation.Date
import struct Foundation.UUID
#endif
import NIOCore
import NIOHTTP1
import NIOSSL

/// A client to talk with the Apple Push Notification services.
public final class APNSClient<Decoder: APNSJSONDecoder, Encoder: APNSJSONEncoder>: APNSClientProtocol {
   
    /// The configuration used by the ``APNSClient``.
    private let configuration: APNSClientConfiguration
    
    /// The ``HTTPClient`` used by the APNS.
    private let httpClient: HTTPClient
    
    /// The decoder for the responses from APNs.
    private let responseDecoder: Decoder
    
    /// The encoder for the requests to APNs.
    @usableFromInline
    /* private */ internal let requestEncoder: Encoder
    
    /// The authentication token manager.
    private let authenticationTokenManager: APNSAuthenticationTokenManager<ContinuousClock>?
    
    /// The ByteBufferAllocator
    @usableFromInline
    /* private */ internal let byteBufferAllocator: ByteBufferAllocator
    
    /// Default ``HTTPHeaders`` which will be adapted for each request. This saves some allocations.
    private let defaultRequestHeaders: HTTPHeaders = {
        var headers = HTTPHeaders()
        headers.reserveCapacity(10)
        headers.add(name: "content-type", value: "application/json")
        headers.add(name: "user-agent", value: "APNS/swift-nio")
        return headers
    }()

    /// Initializes a new APNS.
    ///
    /// The client will create an internal `HTTPClient` which is used to make requests to APNs.
    /// This `HTTPClient` is intentionally internal since both authentication mechanisms are bound to a
    /// single connection and these connections cannot be shared.
    ///
    ///
    /// - Parameters:
    ///   - configuration: The configuration used by the APNS.
    ///   - eventLoopGroupProvider: Specify how EventLoopGroup will be created.
    ///   - responseDecoder: The decoder for the responses from APNs.
    ///   - requestEncoder: The encoder for the requests to APNs.
    ///   - byteBufferAllocator: The `ByteBufferAllocator`.
    public init(
        configuration: APNSClientConfiguration,
        eventLoopGroupProvider: NIOEventLoopGroupProvider,
        responseDecoder: Decoder,
        requestEncoder: Encoder,
        byteBufferAllocator: ByteBufferAllocator = .init()
    ) {
        self.configuration = configuration
        self.byteBufferAllocator = byteBufferAllocator
        self.responseDecoder = responseDecoder
        self.requestEncoder = requestEncoder

        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        switch configuration.authenticationMethod.method {
        case .jwt(let privateKey, let teamIdentifier, let keyIdentifier):
            self.authenticationTokenManager = APNSAuthenticationTokenManager(
                privateKey: privateKey,
                teamIdentifier: teamIdentifier,
                keyIdentifier: keyIdentifier,
                clock: ContinuousClock()
            )
        case .tls(let privateKey, let certificateChain):
            self.authenticationTokenManager = nil
            tlsConfiguration.privateKey = privateKey
            tlsConfiguration.certificateChain = certificateChain
        }

        var httpClientConfiguration = HTTPClient.Configuration()
        httpClientConfiguration.tlsConfiguration = tlsConfiguration
        httpClientConfiguration.httpVersion = .automatic
        httpClientConfiguration.proxy = configuration.proxy

        switch eventLoopGroupProvider {
        case .shared(let eventLoopGroup):
            self.httpClient = HTTPClient(
                eventLoopGroupProvider: .shared(eventLoopGroup),
                configuration: httpClientConfiguration
            )
        case .createNew:
            self.httpClient = HTTPClient(
                configuration: httpClientConfiguration
            )
        }
    }

    /// Shuts down the client gracefully.
    public func shutdown() async throws {
        try await self.httpClient.shutdown()
    }
}

extension APNSClient: Sendable where Decoder: Sendable, Encoder: Sendable {}

// MARK: - Raw sending

extension APNSClient {
    
    public func send(_ request: APNSCore.APNSRequest<some APNSCore.APNSMessage>) async throws -> APNSCore.APNSResponse {
        var headers = self.defaultRequestHeaders

        // Push type
        headers.add(name: "apns-push-type", value: request.pushType.description)

        // APNS ID
        if let apnsID = request.apnsID {
            headers.add(name: "apns-id", value: apnsID.uuidString.lowercased())
        }

        // Expiration
        if let expiration = request.expiration?.expiration {
            headers.add(name: "apns-expiration", value: String(expiration))
        }

        // Priority
        if let priority = request.priority?.rawValue {
            headers.add(name: "apns-priority", value: String(priority))
        }

        // Topic
        if let topic = request.topic {
            headers.add(name: "apns-topic", value: topic)
        }

        // Collapse ID
        if let collapseID = request.collapseID {
            headers.add(name: "apns-collapse-id", value: collapseID)
        }

        // Authorization token
        if let authenticationTokenManager = self.authenticationTokenManager {
            let token = try await authenticationTokenManager.nextValidToken
            headers.add(name: "authorization", value: token)
        }

        // Device token
        let requestURL = "\(self.configuration.environment.absoluteURL)/\(request.deviceToken)"
        var byteBuffer = self.byteBufferAllocator.buffer(capacity: 0)

        try self.requestEncoder.encode(request.message, into: &byteBuffer)
        
        var httpClientRequest = HTTPClientRequest(url: requestURL)
        httpClientRequest.method = .POST
        httpClientRequest.headers = headers
        httpClientRequest.body = .bytes(byteBuffer)

        let response = try await self.httpClient.execute(httpClientRequest, deadline: .distantFuture)

        let apnsID = response.headers.first(name: "apns-id").flatMap { UUID(uuidString: $0) }
        let apnsUniqueID = response.headers.first(name: "apns-unique-id").flatMap { UUID(uuidString: $0) }

        if response.status == .ok {
            return APNSResponse(apnsID: apnsID, apnsUniqueID: apnsUniqueID)
        }

        // An empty body, non-JSON body, or a body exceeding the collection limit must still
        // surface as a typed `APNSError` (with `reason: nil`) rather than a raw decoding error,
        // so the caller never loses the status code and headers.
        let body = try? await response.body.collect(upTo: 1024)
        let errorResponse = body.flatMap { try? responseDecoder.decode(APNSErrorResponse.self, from: $0) }

        let error = APNSError(
            responseStatus: Int(response.status.code),
            apnsID: apnsID,
            apnsUniqueID: apnsUniqueID,
            apnsResponse: errorResponse,
            timestamp: errorResponse?.timestampInSeconds.flatMap { Date(timeIntervalSince1970: $0) }
        )

        throw error
    }

    /// Publishes a broadcast push notification.
    ///
    /// Broadcast pushes are sent to the regular device-push host (``APNSCore/APNSEnvironment``), not the
    /// channel-management host, and are Live Activities only.
    ///
    /// - Parameter request: The broadcast send request.
    public func sendBroadcast<Message: APNSCore.APNSMessage>(
        _ request: APNSCore.APNSBroadcastSendRequest<Message>
    ) async throws -> APNSCore.APNSBroadcastSendResponse {
        var headers = self.defaultRequestHeaders

        // Broadcast headers (apns-channel-id, apns-push-type, apns-expiration, apns-priority, apns-request-id)
        for (name, value) in request.headers {
            headers.add(name: name, value: value)
        }

        // Authorization token
        if let authenticationTokenManager = self.authenticationTokenManager {
            let token = try await authenticationTokenManager.nextValidToken
            headers.add(name: "authorization", value: token)
        }

        let requestURL = self.configuration.environment.broadcastSendURL(bundleID: request.bundleID)
        var byteBuffer = self.byteBufferAllocator.buffer(capacity: 0)

        try self.requestEncoder.encode(request.message, into: &byteBuffer)

        var httpClientRequest = HTTPClientRequest(url: requestURL)
        httpClientRequest.method = .POST
        httpClientRequest.headers = headers
        httpClientRequest.body = .bytes(byteBuffer)

        let response = try await self.httpClient.execute(httpClientRequest, deadline: .distantFuture)

        let apnsRequestID = response.headers.first(name: "apns-request-id").flatMap { UUID(uuidString: $0) }
        let apnsUniqueID = response.headers.first(name: "apns-unique-id").flatMap { UUID(uuidString: $0) }

        if response.status == .ok {
            return APNSBroadcastSendResponse(apnsRequestID: apnsRequestID, apnsUniqueID: apnsUniqueID)
        }

        let body = try await response.body.collect(upTo: 1024)
        let errorResponse = try responseDecoder.decode(APNSErrorResponse.self, from: body)

        let error = APNSError(
            responseStatus: Int(response.status.code),
            apnsID: nil,
            apnsUniqueID: apnsUniqueID,
            apnsResponse: errorResponse,
            timestamp: errorResponse.timestampInSeconds.flatMap { Date(timeIntervalSince1970: $0) }
        )

        throw error
    }
}

// MARK: - Broadcast convenience

extension APNSClient {

    /// Publishes a broadcast Live Activity update (or end) notification.
    ///
    /// - Important: Broadcast is Live Activities only and cannot be used to *start* an activity.
    ///
    /// - Parameters:
    ///   - notification: The Live Activity notification to broadcast.
    ///   - channelID: The base64-encoded channel ID to publish the broadcast on.
    ///   - bundleID: The app's bundle identifier used in the API path.
    ///   - apnsRequestID: An optional request ID for tracking.
    @discardableResult
    public func sendBroadcastLiveActivityNotification<ContentState: Encodable & Sendable>(
        _ notification: APNSCore.APNSLiveActivityNotification<ContentState>,
        channelID: String,
        bundleID: String,
        apnsRequestID: UUID? = nil
    ) async throws -> APNSCore.APNSBroadcastSendResponse {
        let request = APNSCore.APNSBroadcastSendRequest(
            message: notification,
            channelID: channelID,
            bundleID: bundleID,
            expiration: notification.expiration,
            priority: notification.priority,
            apnsRequestID: apnsRequestID
        )
        return try await sendBroadcast(request)
    }
}
