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
import Foundation
import NIOConcurrencyHelpers
import Testing

struct APNSAuthenticationTokenManagerTests {
    private static let signingKey = """
    -----BEGIN EC PRIVATE KEY-----
    MHcCAQEEIPnrjgMs/LOp9W5R2kQtdBfzyjCe2wICBOWgyCA6OwRDoAoGCCqGSM49
    AwEHoUQDQgAEbWmxH/HLvIJIVUt8bB42ntiBZUSb6Bxx7F36mDSHssBaRBU0BYYj
    NVeBKbgP2rVE/nOAexjhmWE2S5G98nkEPg==
    -----END EC PRIVATE KEY-----

    """
    private let clock: TestClock<Duration>
    private let tokenManager: APNSAuthenticationTokenManager<TestClock<Duration>>

    init() throws {
        let clock = TestClock<Duration>()
        self.clock = clock
        self.tokenManager = APNSAuthenticationTokenManager(
            privateKey: try .init(pemRepresentation: Self.signingKey),
            teamIdentifier: "foo",
            keyIdentifier: "bar",
            clock: clock
        )
    }

    @Test func token() async throws {
        let token = try await tokenManager.nextValidToken

        // We need to split twice here since the expected format of the token is
        // "bearer encodedHeader.encodedPayload.ecnodedSignature"
        let splitToken = try #require(token.split(separator: " ").last)
            .split(separator: ".")

        let decodedHeader = try #require(base64URLDecoded(String(splitToken[0])))
        let header = String(data: decodedHeader, encoding: .utf8)
        let expectedHeader = """
        {
            "alg": "ES256",
            "typ": "JWT",
            "kid": "bar"
        }
        """
        #expect(header == expectedHeader)

        let decodedPayload = try #require(base64URLDecoded(String(splitToken[1])))

        // The expected `iat` is computed *after* token generation, so comparing raw strings
        // is flaky across second boundaries. Instead, decode the JSON and assert `iss` plus
        // an `iat` that's within a few seconds of "now".
        struct Payload: Decodable {
            let iss: String
            let iat: Int64
        }
        let payload = try JSONDecoder().decode(Payload.self, from: decodedPayload)
        let now = Date().timeIntervalSince1970

        #expect(payload.iss == "foo")
        #expect(abs(Double(payload.iat) - now) <= 5)
    }

    /// The refresh window is `[0, 55min)`: a token is still considered valid one
    /// second before 55 minutes, and refreshed at exactly 55 minutes.
    @Test func `Token reused just before boundary and refreshed at boundary`() async throws {
        let token1 = try await tokenManager.nextValidToken

        // 54:59 — still inside the window, so the cached token is returned.
        clock.now = clock.now.advanced(by: .init(secondsComponent: 3299, attosecondsComponent: 0))
        let reused = try await tokenManager.nextValidToken
        #expect(token1 == reused)

        // 55:00 — `duration(to:)` is no longer `< 55min`, so a fresh token is generated.
        clock.now = clock.now.advanced(by: .init(secondsComponent: 1, attosecondsComponent: 0))
        let refreshed = try await tokenManager.nextValidToken
        #expect(token1 != refreshed)
    }

    /// A refreshed token must be a well-formed JWT with the correct claims — not merely
    /// a different string (ECDSA signatures are randomized, so string inequality alone is weak).
    @Test func `Refreshed token is structurally valid`() async throws {
        _ = try await tokenManager.nextValidToken

        clock.now = clock.now.advanced(by: .init(secondsComponent: 3360, attosecondsComponent: 0))
        let refreshed = try await tokenManager.nextValidToken

        let segments = try #require(refreshed.split(separator: " ").last).split(separator: ".")
        #expect(segments.count == 3, "Expected a `header.payload.signature` JWT")

        let header = try decodeSegment(segments[0])
        #expect(header.contains("\"kid\": \"bar\""))
        #expect(header.contains("\"alg\": \"ES256\""))

        let payload = try decodeSegment(segments[1])
        #expect(payload.contains("\"iss\": \"foo\""))
        #expect(!payload.contains("\"kid\""), "kid must not be duplicated into the payload")
    }

    private func decodeSegment(_ segment: Substring) throws -> String {
        let data = try #require(base64URLDecoded(String(segment)))
        return try #require(String(data: data, encoding: .utf8))
    }
}

final class TestClock<Duration: DurationProtocol & Hashable>: Clock {
    struct Instant: InstantProtocol {
        public var offset: Duration

        public init(offset: Duration = .zero) {
            self.offset = offset
        }

        public func advanced(by duration: Duration) -> Self {
            .init(offset: self.offset + duration)
        }

        public func duration(to other: Self) -> Duration {
            other.offset - self.offset
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    let minimumResolution: Duration = .zero
    private let _now: NIOLockedValueBox<Instant>

    var now: Instant {
        get {
            self._now.withLockedValue { $0 }
        } set {
            self._now.withLockedValue { $0 = newValue }
        }
    }


    public init(now: Instant = .init()) {
        self._now = .init(now)
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
        try await Task.sleep(until: deadline, clock: self)
    }
}
