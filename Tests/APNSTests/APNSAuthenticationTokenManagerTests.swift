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
import Crypto
import XCTest
import NIOConcurrencyHelpers

final class APNSAuthenticationTokenManagerTests: XCTestCase {
    private static let signingKey = """
    -----BEGIN EC PRIVATE KEY-----
    MHcCAQEEIPnrjgMs/LOp9W5R2kQtdBfzyjCe2wICBOWgyCA6OwRDoAoGCCqGSM49
    AwEHoUQDQgAEbWmxH/HLvIJIVUt8bB42ntiBZUSb6Bxx7F36mDSHssBaRBU0BYYj
    NVeBKbgP2rVE/nOAexjhmWE2S5G98nkEPg==
    -----END EC PRIVATE KEY-----
    
    """
    private var clock: TestClock<Duration>!
    private var tokenManager: APNSAuthenticationTokenManager<TestClock<Duration>>!
    
    override func setUp() {
        super.setUp()
        clock = TestClock()
        tokenManager = APNSAuthenticationTokenManager(
            privateKey: try! .init(pemRepresentation: Self.signingKey),
            teamIdentifier: "foo",
            keyIdentifier: "bar",
            clock: clock
        )
    }
    
    override func tearDown() {
        super.tearDown()
        
        tokenManager = nil
        clock = nil
    }
    
    func testToken() async throws {
        let token = try await tokenManager.nextValidToken
        
        // We need to split twice here since the expected format of the token is
        // "bearer encodedHeader.encodedPayload.ecnodedSignature"
        let splitToken = try XCTUnwrap(token.split(separator: " ").last)
            .split(separator: ".")
        
        let decodedHeader = try Base64.decode(
            string: String(splitToken[0]),
            options: [.base64UrlAlphabet, .omitPaddingCharacter]
        )
        let header = String(bytes: decodedHeader, encoding: .utf8)
        let expectedHeader = """
        {
            "alg": "ES256",
            "typ": "JWT",
            "kid": "bar"
        }
        """
        XCTAssertEqual(header, expectedHeader)
        
        let decodedPayload = try Base64.decode(
            string: String(splitToken[1]),
            options: [.base64UrlAlphabet, .omitPaddingCharacter]
        )
        let payload = String(bytes: decodedPayload, encoding: .utf8)
        let issuedAtTime = DispatchWallTime.now()
        let expectedPayload = """
        {
            "iss": "foo",
            "iat": "\(issuedAtTime.asSecondsSince1970)",
            "kid": "bar"
        }
        """
        XCTAssertEqual(payload, expectedPayload)
    }
    
        func testTokenIsReused() async throws {
   
            let token1 = try await tokenManager.nextValidToken
            // 48 minutes later
            let temp = clock.now.advanced(by: .init(secondsComponent: 2880, attosecondsComponent: 0))
            clock.now = temp
            let token2 = try await tokenManager.nextValidToken
    
            XCTAssertEqual(token1, token2)
        }

    func testTokenIsRefreshed() async throws {
        let token1 = try await tokenManager.nextValidToken

        // 56 minutes later
        let temp = clock.now.advanced(by: .init(secondsComponent: 3360, attosecondsComponent: 0))
        clock.now = temp
        let token2 = try await tokenManager.nextValidToken

        XCTAssertNotEqual(token1, token2)
    }

    /// The refresh window is `[0, 55min)`: a token is still considered valid one
    /// second before 55 minutes, and refreshed at exactly 55 minutes.
    func testTokenReusedJustBeforeBoundaryAndRefreshedAtBoundary() async throws {
        let token1 = try await tokenManager.nextValidToken

        // 54:59 — still inside the window, so the cached token is returned.
        clock.now = clock.now.advanced(by: .init(secondsComponent: 3299, attosecondsComponent: 0))
        let reused = try await tokenManager.nextValidToken
        XCTAssertEqual(token1, reused)

        // 55:00 — `duration(to:)` is no longer `< 55min`, so a fresh token is generated.
        clock.now = clock.now.advanced(by: .init(secondsComponent: 1, attosecondsComponent: 0))
        let refreshed = try await tokenManager.nextValidToken
        XCTAssertNotEqual(token1, refreshed)
    }

    /// A refreshed token must be a well-formed JWT with the correct claims — not merely
    /// a different string (ECDSA signatures are randomized, so string inequality alone is weak).
    func testRefreshedTokenIsStructurallyValid() async throws {
        _ = try await tokenManager.nextValidToken

        clock.now = clock.now.advanced(by: .init(secondsComponent: 3360, attosecondsComponent: 0))
        let refreshed = try await tokenManager.nextValidToken

        let segments = try XCTUnwrap(refreshed.split(separator: " ").last).split(separator: ".")
        XCTAssertEqual(segments.count, 3, "Expected a `header.payload.signature` JWT")

        let header = try decodeSegment(segments[0])
        XCTAssertTrue(header.contains("\"kid\": \"bar\""))
        XCTAssertTrue(header.contains("\"alg\": \"ES256\""))

        let payload = try decodeSegment(segments[1])
        XCTAssertTrue(payload.contains("\"iss\": \"foo\""))
        XCTAssertTrue(payload.contains("\"kid\": \"bar\""))
    }

    private func decodeSegment(_ segment: Substring) throws -> String {
        let bytes = try Base64.decode(
            string: String(segment),
            options: [.base64UrlAlphabet, .omitPaddingCharacter]
        )
        return try XCTUnwrap(String(bytes: bytes, encoding: .utf8))
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
