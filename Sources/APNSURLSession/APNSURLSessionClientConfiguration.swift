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
@preconcurrency import Crypto

/// The configuration of an ``APNSURLSessionClient``.
public struct APNSURLSessionClientConfiguration {
    /// The authentication method used by the ``APNSURLSessionClient``.
    public enum AuthenticationMethod {
        case jwt(privateKey: P256.Signing.PrivateKey, teamIdentifier: String, keyIdentifier: String)
    }

    /// The environment used by the ``APNSURLSessionClient``.
    public var environment: APNSEnvironment

    /// Type-erased access to the generic ``APNSAuthenticationTokenManager``.
    ///
    /// The token manager is generic over its ``Clock``, but this configuration is not, so the
    /// concrete, caller-injected clock is captured in this closure at ``init`` time rather than
    /// stored as a typed property.
    private let nextValidTokenClosure: @Sendable () async throws -> String

    internal func nextValidToken() async throws -> String {
        try await nextValidTokenClosure()
    }

    /// Initializes a new ``APNSClient.Configuration``.
    ///
    /// - Parameters:
    ///   - environment: The environment used by the ``APNSURLSessionClient``.
    ///   - privateKey: The private encryption key obtained through the developer portal.
    ///   - keyIdentifier: The private encryption key identifier obtained through the developer portal.
    ///   - teamIdentifier: The team id.
    ///   - clock: The clock used to determine when a generated authentication token has expired.
    public init<APNSClock: Clock>(
        environment: APNSEnvironment,
        privateKey: P256.Signing.PrivateKey,
        keyIdentifier: String,
        teamIdentifier: String,
        clock: APNSClock = ContinuousClock()
    ) where APNSClock.Duration == Duration {
        self.environment = environment

        let authenticationTokenManager = APNSAuthenticationTokenManager(
            privateKey: privateKey,
            teamIdentifier: teamIdentifier,
            keyIdentifier: keyIdentifier,
            clock: clock
        )
        self.nextValidTokenClosure = {
            try await authenticationTokenManager.nextValidToken
        }
    }
}

