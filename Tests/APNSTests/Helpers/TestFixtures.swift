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
import APNSTestServer
import AsyncHTTPClient
import Crypto
import Foundation
import NIOPosix
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import APNSURLSession
#endif

enum TestFixtures {
    static let keyIdentifier = "MY_KEY_ID"
    static let teamIdentifier = "MY_TEAM_ID"
    static let validDeviceToken = String(repeating: "a", count: 64)

    static let jwtPrivateKey = """
    -----BEGIN PRIVATE KEY-----
    MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg2sD+kukkA8GZUpmm
    jRa4fJ9Xa/JnIG4Hpi7tNO66+OGgCgYIKoZIzj0DAQehRANCAATZp0yt0btpR9kf
    ntp4oUUzTV0+eTELXxJxFvhnqmgwGAm1iVW132XLrdRG/ntlbQ1yzUuJkHtYBNve
    y+77Vzsd
    -----END PRIVATE KEY-----
    """

    static func signingKey() throws -> P256.Signing.PrivateKey {
        try P256.Signing.PrivateKey(pemRepresentation: jwtPrivateKey)
    }

    static func jwtAuthentication() throws -> APNSClientConfiguration.AuthenticationMethod {
        .jwt(privateKey: try signingKey(), keyIdentifier: keyIdentifier, teamIdentifier: teamIdentifier)
    }

    static func withServer<T>(_ body: (APNSTestServer) async throws -> T) async throws -> T {
        let server = APNSTestServer()
        try await server.start(port: 0)
        do {
            let result = try await body(server)
            try await server.shutdown()
            return result
        } catch {
            try? await server.shutdown()
            throw error
        }
    }

    static func withClient<T>(
        _ body: (APNSTestServer, APNSClient<JSONDecoder, JSONEncoder>) async throws -> T
    ) async throws -> T {
        try await withServer { server in
            let client = APNSClient(
                configuration: .init(
                    authenticationMethod: try jwtAuthentication(),
                    environment: .custom(url: "http://127.0.0.1", port: server.port)
                ),
                eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder()
            )
            do {
                let result = try await body(server, client)
                try await client.shutdown()
                return result
            } catch {
                try? await client.shutdown()
                throw error
            }
        }
    }

    static func withBroadcastClient<T>(
        bundleID: String = "com.example.testapp",
        _ body: (APNSTestServer, APNSBroadcastClient<JSONDecoder, JSONEncoder>) async throws -> T
    ) async throws -> T {
        try await withServer { server in
            let client = APNSBroadcastClient(
                authenticationMethod: try jwtAuthentication(),
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                bundleID: bundleID,
                eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder()
            )
            do {
                let result = try await body(server, client)
                try await client.shutdown()
                return result
            } catch {
                try? await client.shutdown()
                throw error
            }
        }
    }

    static func withRawHTTPClient<T>(
        _ body: (APNSTestServer, HTTPClient) async throws -> T
    ) async throws -> T {
        try await withServer { server in
            let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            do {
                let result = try await body(server, httpClient)
                try await httpClient.shutdown()
                return result
            } catch {
                try? await httpClient.shutdown()
                throw error
            }
        }
    }

    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    static func urlSessionClient(for server: APNSTestServer, session: URLSession = .shared) throws -> APNSURLSessionClient {
        APNSURLSessionClient(
            configuration: .init(
                environment: .custom(url: "http://127.0.0.1", port: server.port),
                privateKey: try signingKey(),
                keyIdentifier: keyIdentifier,
                teamIdentifier: teamIdentifier
            ),
            session: session
        )
    }
    #endif
}
