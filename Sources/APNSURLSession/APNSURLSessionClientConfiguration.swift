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
public struct APNSURLSessionClientConfiguration: Sendable {
    /// The authentication method used by the ``APNSURLSessionClient``.
    public enum AuthenticationMethod: Sendable {
        case jwt(privateKey: P256.Signing.PrivateKey, teamIdentifier: String, keyIdentifier: String)
    }

    /// The authentication method used by the ``APNSURLSessionClient``.
    public var authenticationMethod: AuthenticationMethod

    /// The environment used by the ``APNSURLSessionClient``.
    public var environment: APNSEnvironment
    
    private let authenticationTokenManager: APNSAuthenticationTokenManager<ContinuousClock>
    
    internal func nextValidToken() async throws -> String {
        try await authenticationTokenManager.nextValidToken
    }

    /// Initializes a new ``APNSClient.Configuration``.
    ///
    /// - Parameters:
    ///   - environment: The environment used by the ``APNSURLSessionClient``.
    ///   - privateKey: The private encryption key obtained through the developer portal.
    ///   - keyIdentifier: The private encryption key identifier obtained through the developer portal.
    ///   - teamIdentifier: The team id.
    public init(
        environment: APNSEnvironment,
        privateKey: P256.Signing.PrivateKey,
        keyIdentifier: String,
        teamIdentifier: String,
        clock: any Clock = ContinuousClock()
    ) {
        self.authenticationMethod = .jwt(privateKey: privateKey, teamIdentifier: teamIdentifier, keyIdentifier: keyIdentifier)
        self.environment = environment
        
        self.authenticationTokenManager = APNSAuthenticationTokenManager(
            privateKey: privateKey,
            teamIdentifier: teamIdentifier,
            keyIdentifier: keyIdentifier,
            clock: ContinuousClock()
        )
    }
}

