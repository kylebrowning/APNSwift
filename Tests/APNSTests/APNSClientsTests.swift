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
import APNS
import APNSCore
import Foundation
import Testing

struct APNSClientsTests {
    @Test func `configure registers production and development`() async throws {
        let apns = APNSClients()
        await apns.configure(try TestFixtures.jwtAuthentication())

        let production = await apns.client(for: .production)
        let development = await apns.client(for: .development)
        #expect(production != nil)
        #expect(development != nil)
        #expect(production !== development)
        #expect(await apns.client === production)

        try await apns.shutdown()
    }

    @Test func `First registration is the default unless told otherwise`() async throws {
        let apns = APNSClients()
        #expect(await apns.client(for: nil) == nil)
        #expect(await apns.client(for: .default) == nil)

        await apns.use(try Self.configuration(), as: .default)
        await apns.use(try Self.configuration(), as: .custom)
        #expect(await apns.client === apns.client(.default))

        await apns.use(try Self.configuration(), as: .development, isDefault: true)
        #expect(await apns.client === apns.client(.development))

        await apns.default(to: .custom)
        #expect(await apns.client === apns.client(.custom))

        try await apns.shutdown()
    }

    @Test func `Registering under an existing ID replaces the client`() async throws {
        let apns = APNSClients()
        await apns.use(try Self.configuration(), as: .default)
        let first = try #require(await apns.client(for: .default))
        await apns.use(try Self.configuration(), as: .default)
        let second = try #require(await apns.client(for: .default))
        #expect(first !== second)

        try await first.shutdown()
        try await apns.shutdown()
    }

    @Test func `Shutdown empties the set`() async throws {
        let apns = APNSClients()
        await apns.configure(try TestFixtures.jwtAuthentication())
        try await apns.shutdown()
        #expect(await apns.client(for: nil) == nil)
        #expect(await apns.client(for: .production) == nil)

        // Shutting down an empty set is harmless.
        try await apns.shutdown()
    }

    @Test func `Sends through a registered client`() async throws {
        try await TestFixtures.withServer { server in
            let apns = APNSClients()
            await apns.use(
                .init(
                    authenticationMethod: try TestFixtures.jwtAuthentication(),
                    environment: .custom(url: "http://127.0.0.1", port: server.port)
                ),
                as: .custom
            )

            let response = try await apns.client.sendAlertNotification(
                APNSAlertNotification(
                    alert: .init(title: .raw("Hi")),
                    expiration: .immediately,
                    priority: .immediately,
                    topic: "com.example.app",
                    payload: EmptyPayload()
                ),
                deviceToken: TestFixtures.validDeviceToken
            )
            #expect(response.apnsID != nil)
            #expect(server.getSentNotifications().count == 1)

            try await apns.shutdown()
        }
    }

    private static func configuration() throws -> APNSClientConfiguration {
        .init(authenticationMethod: try TestFixtures.jwtAuthentication(), environment: .development)
    }
}

extension APNSClients.ID {
    fileprivate static var custom: Self { .init(string: "custom") }
}
