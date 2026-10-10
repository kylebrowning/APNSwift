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
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

#if canImport(FoundationEssentials)
    import class FoundationEssentials.JSONDecoder
    import class FoundationEssentials.JSONEncoder
#else
    import class Foundation.JSONDecoder
    import class Foundation.JSONEncoder
#endif
#if ServiceLifecycleSupport
    import ServiceLifecycle
#endif

/// A set of ``APNSClient``s looked up by ``APNSClients/ID``.
///
/// Most apps need one client for Apple's production environment and one for development, since a
/// device token only works against the environment the app was built for. ``configure(_:eventLoopGroupProvider:)``
/// registers that pair from a single key:
///
/// ```swift
/// let apns = APNSClients()
/// await apns.configure(.jwt(
///     privateKey: try .init(pemRepresentation: privateKey),
///     keyIdentifier: keyIdentifier,
///     teamIdentifier: teamIdentifier
/// ))
///
/// try await apns.client(.development).sendAlertNotification(notification, deviceToken: token)
/// ```
///
/// With the `ServiceLifecycleSupport` trait enabled, which it is by default, ``APNSClients`` is a
/// `Service`. Add it to your `ServiceGroup` and every registered client is shut down when the group
/// shuts down. Add either the set or its clients to the group, not both.
///
/// Without the trait, call ``shutdown()`` yourself.
public final actor APNSClients {
    /// The default JSON coders are used for every client in the set.
    public typealias Client = APNSClient<JSONDecoder, JSONEncoder>

    /// Identifies a client in an ``APNSClients`` set.
    public struct ID: Sendable, Hashable, Codable, CustomStringConvertible {
        public let string: String

        public init(string: String) {
            self.string = string
        }

        public var description: String { self.string }

        /// The ID ``configure(_:eventLoopGroupProvider:)`` registers the production client under.
        public static var production: ID { ID(string: "production") }

        /// The ID ``configure(_:eventLoopGroupProvider:)`` registers the development client under.
        public static var development: ID { ID(string: "development") }

        /// A general purpose ID for apps that only need one client.
        public static var `default`: ID { ID(string: "default") }
    }

    private var clients: [ID: Client] = [:]
    private var defaultID: ID?
    private let isRunning = NIOLockedValueBox(false)

    public init() {}

    /// Creates a client for `configuration` and registers it under `id`.
    ///
    /// - Parameters:
    ///   - configuration: The client configuration.
    ///   - eventLoopGroupProvider: How the client's event loop group is obtained. Defaults to the
    ///     shared NIO singleton group.
    ///   - responseDecoder: The decoder for responses from APNs.
    ///   - requestEncoder: The encoder for requests to APNs.
    ///   - byteBufferAllocator: The allocator to use.
    ///   - id: The ID to register the client under. Registering a second client under the same ID
    ///     replaces the first without shutting it down.
    ///   - isDefault: Whether ``client`` returns this client. The first client registered without
    ///     passing `false` becomes the default.
    public func use(
        _ configuration: APNSClientConfiguration,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .shared(
            MultiThreadedEventLoopGroup.singleton),
        responseDecoder: JSONDecoder = JSONDecoder(),
        requestEncoder: JSONEncoder = JSONEncoder(),
        byteBufferAllocator: ByteBufferAllocator = .init(),
        as id: ID,
        isDefault: Bool? = nil
    ) {
        self.clients[id] = Client(
            configuration: configuration,
            eventLoopGroupProvider: eventLoopGroupProvider,
            responseDecoder: responseDecoder,
            requestEncoder: requestEncoder,
            byteBufferAllocator: byteBufferAllocator
        )

        if isDefault == true || (self.defaultID == nil && isDefault != false) {
            self.defaultID = id
        }
    }

    /// Registers a production client under ``ID/production`` and a development client under
    /// ``ID/development``, both authenticated with `authenticationMethod`.
    ///
    /// The same key works for both environments. The production client becomes the default unless
    /// one was already chosen.
    public func configure(
        _ authenticationMethod: APNSClientConfiguration.AuthenticationMethod,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .shared(
            MultiThreadedEventLoopGroup.singleton)
    ) {
        self.use(
            APNSClientConfiguration(
                authenticationMethod: authenticationMethod, environment: .production),
            eventLoopGroupProvider: eventLoopGroupProvider,
            as: .production
        )
        self.use(
            APNSClientConfiguration(
                authenticationMethod: authenticationMethod, environment: .development),
            eventLoopGroupProvider: eventLoopGroupProvider,
            as: .development
        )
    }

    /// Makes the client registered under `id` the one client returns.
    public func `default`(to id: ID) {
        self.defaultID = id
    }

    /// The client registered under `id`, or the default client when `id` is `nil`.
    public func client(for id: ID? = nil) -> Client? {
        guard let id = id ?? self.defaultID else { return nil }
        return self.clients[id]
    }

    /// The default client.
    ///
    /// - Precondition: A client has been registered.
    public var client: Client {
        guard let client = self.client(for: nil) else {
            preconditionFailure("No default APNs client has been registered.")
        }
        return client
    }

    /// The client registered under `id`.
    ///
    /// - Precondition: A client has been registered under `id`.
    public func client(_ id: ID) -> Client {
        guard let client = self.client(for: id) else {
            preconditionFailure("No APNs client has been registered as \(id).")
        }
        return client
    }

    /// Shuts down every registered client and empties the set.
    ///
    /// Every client is shut down even if one fails. The first failure is rethrown afterwards.
    public func shutdown() async throws {
        let clients = self.clients.values
        self.clients.removeAll()
        self.defaultID = nil

        var firstError: (any Error)?
        for client in clients {
            do {
                try await client.shutdown()
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError {
            throw firstError
        }
    }
}

#if ServiceLifecycleSupport
    extension APNSClients: Service {
        /// Keeps the clients alive until graceful shutdown is triggered, then shuts them all down.
        ///
        /// Cancelling the task running `run()` also shuts the clients down.
        ///
        /// - Precondition: `run()` is called at most once.
        public func run() async throws {
            self.isRunning.markRunning(client: "APNSClients")
            try? await gracefulShutdown()
            try await self.shutdown()
        }
    }
#endif
