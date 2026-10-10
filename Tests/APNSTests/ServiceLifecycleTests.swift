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
#if ServiceLifecycleSupport
    import APNS
    import APNSCore
    import Foundation
    import Logging
    import NIOPosix
    import ServiceLifecycle
    import Testing

    struct ServiceLifecycleTests {
        @Test func `APNSClient shuts down when its run task is cancelled`() async throws {
            let client = try Self.makeClient()
            await withTaskGroup(of: Void.self) { group in
                group.addTask { try? await client.run() }
                group.cancelAll()
            }
            await #expect(throws: (any Error).self) {
                try await client.shutdown()
            }
        }

        @Test func `APNSBroadcastClient shuts down when its run task is cancelled`() async throws {
            let client = APNSBroadcastClient(
                authenticationMethod: try TestFixtures.jwtAuthentication(),
                environment: .development,
                bundleID: "com.example.app",
                eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder()
            )
            await withTaskGroup(of: Void.self) { group in
                group.addTask { try? await client.run() }
                group.cancelAll()
            }
            await #expect(throws: (any Error).self) {
                try await client.shutdown()
            }
        }

        @Test func `APNSClients shuts down with its service group`() async throws {
            let apns = APNSClients()
            await apns.configure(try TestFixtures.jwtAuthentication())
            let group = ServiceGroup(
                services: [apns],
                gracefulShutdownSignals: [],
                logger: Logger(label: "test")
            )

            try await withThrowingTaskGroup(of: Void.self) { tasks in
                tasks.addTask { try await group.run() }
                // Give the group a chance to start the service before shutting it down.
                try await Task.sleep(for: .milliseconds(10))
                await group.triggerGracefulShutdown()
                try await tasks.waitForAll()
            }

            #expect(await apns.client(for: .production) == nil)
            #expect(await apns.client(for: .development) == nil)
        }

        @Test func `APNSClient shuts down with its service group`() async throws {
            let client = try Self.makeClient()
            let group = ServiceGroup(
                services: [client],
                gracefulShutdownSignals: [],
                logger: Logger(label: "test")
            )

            try await withThrowingTaskGroup(of: Void.self) { tasks in
                tasks.addTask { try await group.run() }
                try await Task.sleep(for: .milliseconds(10))
                await group.triggerGracefulShutdown()
                try await tasks.waitForAll()
            }

            await #expect(throws: (any Error).self) {
                try await client.shutdown()
            }
        }

        private static func makeClient() throws -> APNSClient<JSONDecoder, JSONEncoder> {
            APNSClient(
                configuration: .init(
                    authenticationMethod: try TestFixtures.jwtAuthentication(),
                    environment: .development
                ),
                eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder()
            )
        }
    }
#endif
