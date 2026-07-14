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
import AsyncHTTPClient
#if canImport(FoundationEssentials)
import struct FoundationEssentials.Date
import struct FoundationEssentials.UUID
#else
import struct Foundation.Date
import struct Foundation.UUID
#endif
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOSSL
import NIOTLS
import NIOPosix

/// A client for managing Apple Push Notification broadcast channels.
public final class APNSBroadcastClient<Decoder: APNSJSONDecoder & Sendable, Encoder: APNSJSONEncoder & Sendable>: APNSBroadcastClientProtocol {

    /// The broadcast environment to use.
    private let environment: APNSBroadcastEnvironment

    /// The app's bundle identifier used in the API path.
    private let bundleID: String

    /// The ``HTTPClient`` used by the APNS broadcast client.
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

    /// Initializes a new APNSBroadcastClient.
    ///
    /// The client will create an internal ``HTTPClient`` which is used to make requests to APNs broadcast API.
    ///
    /// - Parameters:
    ///   - authenticationMethod: The authentication method to use.
    ///   - environment: The broadcast environment (production or sandbox).
    ///   - bundleID: The app's bundle identifier (e.g., "com.example.myapp").
    ///   - eventLoopGroupProvider: Specify how EventLoopGroup will be created.
    ///   - responseDecoder: The decoder for the responses from APNs.
    ///   - requestEncoder: The encoder for the requests to APNs.
    ///   - byteBufferAllocator: The `ByteBufferAllocator`.
    ///   - proxy: Upstream proxy, defaults to no proxy.
    public init(
        authenticationMethod: APNSClientConfiguration.AuthenticationMethod,
        environment: APNSBroadcastEnvironment,
        bundleID: String,
        eventLoopGroupProvider: NIOEventLoopGroupProvider,
        responseDecoder: Decoder,
        requestEncoder: Encoder,
        byteBufferAllocator: ByteBufferAllocator = .init(),
        proxy: HTTPClient.Configuration.Proxy? = nil
    ) {
        self.environment = environment
        self.bundleID = bundleID
        self.byteBufferAllocator = byteBufferAllocator
        self.responseDecoder = responseDecoder
        self.requestEncoder = requestEncoder

        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        switch authenticationMethod.method {
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
        httpClientConfiguration.proxy = proxy

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

extension APNSBroadcastClient: Sendable where Decoder: Sendable, Encoder: Sendable {}

// MARK: - Broadcast operations

extension APNSBroadcastClient {

    public func send<Message: Encodable & Sendable, ResponseBody: Decodable & Sendable>(
        _ request: APNSBroadcastRequest<Message>
    ) async throws -> APNSBroadcastResponse<ResponseBody> {
        var headers = self.defaultRequestHeaders

        // Add request ID if present
        if let apnsRequestID = request.apnsRequestID {
            headers.add(name: "apns-request-id", value: apnsRequestID.uuidString.lowercased())
        }

        // Authorization token
        if let authenticationTokenManager = self.authenticationTokenManager {
            let token = try await authenticationTokenManager.nextValidToken
            headers.add(name: "authorization", value: token)
        }

        // Append operation specific HTTPS headers
        if let operationHeaders = request.operation.headers {
            for (name, value) in operationHeaders {
                headers.add(name: name, value: value)
            }
        }

        // Build the request URL
        let requestURL = "\(self.environment.url):\(self.environment.port)/1/apps/\(self.bundleID)\(request.operation.path)"

        // Create HTTP request
        var httpClientRequest = HTTPClientRequest(url: requestURL)
        httpClientRequest.method = HTTPMethod(rawValue: request.operation.httpMethod)
        httpClientRequest.headers = headers

        // Add body for operations that require it (e.g., create)
        if let message = request.message {
            var byteBuffer = self.byteBufferAllocator.buffer(capacity: 0)
            try self.requestEncoder.encode(message, into: &byteBuffer)
            httpClientRequest.body = .bytes(byteBuffer)
        }

        // Execute the request
        let response = try await self.httpClient.execute(httpClientRequest, deadline: .distantFuture)

        // Extract request ID from response
        let apnsRequestID = response.headers.first(name: "apns-request-id").flatMap { UUID(uuidString: $0) }

        // Extract channel ID from response, or from request headers (as 'read' operation doesn't return in payload
        let channelID = response.headers.first(name: "apns-channel-id") ?? request.operation.headers?["apns-channel-id"]

        // Handle successful responses
        if response.status == .ok || response.status == .created || response.status == .noContent {
            let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB max
            // Operations like create/delete return an empty body, so only decode when there
            // are bytes to decode — and when there are, surface decode failures rather than
            // silently dropping a malformed body to `nil`.
            let responseBody = body.readableBytes > 0
                ? try responseDecoder.decode(ResponseBody.self, from: body)
                : nil
            return APNSBroadcastResponse(apnsRequestID: apnsRequestID, channelID: channelID, body: responseBody)
        }

        // Handle error responses. An empty body, non-JSON body, or a body exceeding the
        // collection limit must still surface as a typed `APNSError` (with `reason: nil`)
        // rather than a raw decoding error, so the caller never loses the status code and headers.
        let errorBody = try? await response.body.collect(upTo: 1024)
        let errorResponse = errorBody.flatMap { try? responseDecoder.decode(APNSErrorResponse.self, from: $0) }

        let error = APNSError(
            responseStatus: Int(response.status.code),
            apnsID: nil,
            apnsUniqueID: nil,
            apnsResponse: errorResponse,
            timestamp: errorResponse?.timestampInSeconds.flatMap { Date(timeIntervalSince1970: $0) }
        )

        throw error
    }
}
