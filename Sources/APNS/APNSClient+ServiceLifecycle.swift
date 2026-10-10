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
    import NIOConcurrencyHelpers
    import ServiceLifecycle

    extension APNSClient: Service {
        /// Keeps the client alive until graceful shutdown is triggered, then shuts it down.
        ///
        /// This lets an ``APNSClient`` be added to a `ServiceGroup`. The client has no background
        /// work of its own, so `run()` only waits. Cancelling the task running `run()` also shuts
        /// the client down.
        ///
        /// - Precondition: `run()` is called at most once.
        public func run() async throws {
            self.isRunning.markRunning(client: "APNSClient")
            try? await gracefulShutdown()
            try await self.shutdown()
        }
    }

    extension APNSBroadcastClient: Service {
        /// Keeps the client alive until graceful shutdown is triggered, then shuts it down.
        ///
        /// This lets an ``APNSBroadcastClient`` be added to a `ServiceGroup`. The client has no
        /// background work of its own, so `run()` only waits. Cancelling the task running `run()`
        /// also shuts the client down.
        ///
        /// - Precondition: `run()` is called at most once.
        public func run() async throws {
            self.isRunning.markRunning(client: "APNSBroadcastClient")
            try? await gracefulShutdown()
            try await self.shutdown()
        }
    }

    extension NIOLockedValueBox<Bool> {
        func markRunning(client: @autoclosure () -> String) {
            let wasRunning = self.withLockedValue { running in
                defer { running = true }
                return running
            }
            precondition(!wasRunning, "\(client()).run() may only be called once.")
        }
    }
#endif
