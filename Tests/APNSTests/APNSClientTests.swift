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

@testable import APNSCore
import APNS
import Foundation
import NIOPosix
import NIOSSL
import Testing

struct APNSClientTests {
    @Test func shutdown() async throws {
        let client = try makeClient()
        try await client.shutdown()
    }

    @Test func `TLS authentication constructs and shuts down`() async throws {
        let privateKey = try NIOSSLPrivateKey(bytes: Array(TestFixtures.jwtPrivateKey.utf8), format: .pem)
        let client = APNSClient(
            configuration: .init(
                authenticationMethod: .tls(privateKey: .privateKey(privateKey), certificateChain: []),
                environment: .development
            ),
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder()
        )
        try await client.shutdown()
    }

    @Test func `Response description`() throws {
        let apnsID = try #require(UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890"))
        #expect(
            APNSResponse(apnsID: apnsID).description
                == "APNSResponse(apns-id: abcdef12-3456-7890-abcd-ef1234567890, apns-unique-id: nil)"
        )
        #expect(APNSResponse().description == "APNSResponse(apns-id: nil, apns-unique-id: nil)")
    }

    // MARK: - Helper methods

    private func makeClient() throws -> APNSClient<JSONDecoder, JSONEncoder> {
        APNSClient(
            configuration: .init(
                authenticationMethod: try TestFixtures.jwtAuthentication(),
                environment: .development
            ),
            eventLoopGroupProvider: .createNew,
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder()
        )
    }
}

// This doesn't perform any runtime tests, it just ensures the call to sendAlertNotification
// compiles when called within an actor's isolation context.
actor TestActor {
    func sendAlert(client: APNSClient<JSONDecoder, JSONEncoder>) async throws {
        let notification = APNSAlertNotification(
            alert: .init(title: .raw("title")),
            expiration: .immediately,
            priority: .immediately,
            topic: "",
            payload: ""
        )
        try await client.sendAlertNotification(notification, deviceToken: "")
    }
}
