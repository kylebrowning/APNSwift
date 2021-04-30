//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2019 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import NIO
import NIOHTTP2
import NIOSSL
import JWTKit
import AsyncHTTPClient

/// This is structure that provides the system with common configuration.
public struct APNSwiftConfiguration {
    public typealias APNSProxy = HTTPClient.Configuration.Proxy
    
    public var authenticationMethod: AuthenticationMethod

    public enum AuthenticationMethod {
        public static func jwt(
            key: ECDSAKey,
            keyIdentifier: JWKIdentifier,
            teamIdentifier: String
        ) -> Self {
            let signers = JWTSigners()
            signers.use(.es256(key: key), kid: keyIdentifier, isDefault: true)
            return .jwt(signers, teamIdentifier: teamIdentifier, keyIdentifier: keyIdentifier.string)
        }

        /// Creates a new configuration for AuthenticationMethod with a PEM key and certificate
        ///
        ///
        /// - Note:
        ///   You should only be using this constructor if you are sending a push due to a PassKit pass update.
        ///   For all other types of push notifications, please switch to the newer `.p8` file format.
        ///
        /// - Parameters:
        ///     - privateKeyPath: The path to your private key
        ///     - pemPath: The path to your certificate in PEM format
        ///     - pemPassword: The password for the private key
        public static func tls(
            privateKeyPath: String,
            pemPath: String,
            pemPassword: [UInt8]? = nil
        ) throws -> Self {
            let key: NIOSSLPrivateKey
            if let pemPassword = pemPassword {
                key = try NIOSSLPrivateKey(file: privateKeyPath, format: .pem) { $0(pemPassword) }
            } else {
                key = try NIOSSLPrivateKey(file: privateKeyPath, format: .pem)
            }
            let certificate = try NIOSSLCertificateSource.certificate(.init(file: pemPath, format: .pem))
            return .tls { configuration in
                configuration.privateKey = NIOSSLPrivateKeySource.privateKey(key)
                configuration.certificateVerification = .noHostnameVerification
                configuration.certificateChain = [certificate]
            }
        }

        /// Creates a new configuration for AuthenticationMethod with a PEM key and certificate
        ///
        /// Passhprase Generation:
        ///
        ///     let pwdCallback: NIOSSLPassphraseCallback = { callback in
        ///         callback("Your password here".utf8)
        ///     }
        ///
        /// - Note:
        ///   You should only be using this constructor if you are sending a push due to a PassKit pass update.
        ///   For all other types of push notifications, please switch to the newer `.p8` file format.
        ///
        /// - Parameters:
        ///   - privateKeyPath: The path to your private key
        ///   - pemPath: The path to your certificate in PEM format
        ///   - passphraseCallback: The callback which will generate the password for the keyfile.
        public static func tls<T>(
            privateKeyPath: String,
            pemPath: String,
            passphraseCallback: @escaping NIOSSLPassphraseCallback<T>
        ) throws -> Self
            where T: Collection, T.Element == UInt8
        {
            let key = try NIOSSLPrivateKey(file: privateKeyPath, format: .pem, passphraseCallback: passphraseCallback)
            let certificate = try NIOSSLCertificateSource.certificate(.init(file: pemPath, format: .pem))
            return .tls { configuration in
                configuration.privateKey = NIOSSLPrivateKeySource.privateKey(key)
                configuration.certificateVerification = .noHostnameVerification
                configuration.certificateChain = [certificate]
            }
        }

        /// Creates a new configuration for APNSwift with a PEM key and certificate
        ///
        /// Passhprase Generation:
        ///
        ///     let pwdCallback: NIOSSLPassphraseCallback = { callback in
        ///         callback("Your password here".utf8)
        ///     }
        ///
        /// - Note:
        ///   You should only be using this constructor if you are sending a push due to a PassKit pass update.
        ///   For all other types of push notifications, please switch to the newer `.p8` file format.
        /// - Parameters:
        ///     - keyBytes: The private key bytes
        ///     - certificateBytes: The certificate bytes in PEM format
        ///     - pemPassword: The password for the private key
        public static func tls(
            keyBytes: [UInt8],
            certificateBytes: [UInt8],
            pemPassword: [UInt8]? = nil
        ) throws -> Self {
            let key: NIOSSLPrivateKey
            if let pemPassword = pemPassword {
                key = try NIOSSLPrivateKey(bytes: keyBytes, format: .pem) { $0(pemPassword) }
            } else {
                key = try NIOSSLPrivateKey(bytes: keyBytes, format: .pem)
            }
            let certificate = try NIOSSLCertificateSource.certificate(.init(bytes: certificateBytes, format: .pem))
            return .tls { configuration in
                configuration.privateKey = NIOSSLPrivateKeySource.privateKey(key)
                configuration.certificateVerification = .noHostnameVerification
                configuration.certificateChain = [certificate]
            }
        }

        /// Creates a new configuration for APNSwift with a PEM key and certificate
        ///
        /// Passhprase Generation:
        ///
        ///     let pwdCallback: NIOSSLPassphraseCallback = { callback in
        ///         callback("Your password here".utf8)
        ///     }
        ///
        /// - Note:
        ///   You should only be using this constructor if you are sending a push due to a PassKit pass update.
        ///   For all other types of push notifications, please switch to the newer `.p8` file format.
        /// - Parameters:
        ///   - keyBytes: The private key bytes
        ///   - certificateBytes: The certificate bytes in PEM format
        ///   - passphraseCallback: The callback which will generate the password for the keyfile.
        public static func tls<T>(
            keyBytes: [UInt8],
            certificateBytes: [UInt8],
            passphraseCallback: @escaping NIOSSLPassphraseCallback<T>
        ) throws -> Self
            where T: Collection, T.Element == UInt8
        {
            let key = try NIOSSLPrivateKey(bytes: keyBytes, format: .pem, passphraseCallback: passphraseCallback)
            let certificate = try NIOSSLCertificateSource.certificate(.init(bytes: certificateBytes, format: .pem))
            return .tls { configuration in
                configuration.privateKey = NIOSSLPrivateKeySource.privateKey(key)
                configuration.certificateVerification = .noHostnameVerification
                configuration.certificateChain = [certificate]
            }
        }

        case jwt(JWTSigners, teamIdentifier: String, keyIdentifier: String)
        case tls((inout TLSConfiguration) -> ())
    }

    public var topic: String
    public var environment: Environment
    internal var logger: Logger?
    /// Optional timeout time if the connection does not receive a response.
    public var timeout: TimeAmount? = nil
    /// Upstream proxy, defaults to no proxy.
    public var proxy: APNSProxy? = nil

    public var url: URL {
        switch environment {
        case .production:
            return URL(string: "https://api.push.apple.com")!
        case .sandbox:
            return URL(string: "https://api.development.push.apple.com")!
        }
    }

    internal func makeBearerTokenFactory(on eventLoop: EventLoop) -> APNSwiftBearerTokenFactory? {
        switch self.authenticationMethod {
        case .jwt(let signers, let teamIdentifier, let keyIdentifier):
            return .init(
                eventLoop: eventLoop,
                signers: signers,
                teamIdentifier: teamIdentifier,
                keyIdentifier: keyIdentifier,
                logger: self.logger
            )
        case .tls:
            return nil
        }
    }

    public init(
        authenticationMethod: AuthenticationMethod,
        topic: String,
        environment: APNSwiftConfiguration.Environment,
        logger: Logger? = nil,
        timeout: TimeAmount? = nil,
        proxy: APNSProxy? = nil
    ) {
        self.topic = topic
        self.authenticationMethod = authenticationMethod
        self.environment = environment
        if var logger = logger {
            logger[metadataKey: "origin"] = "APNSwift"
            self.logger = logger
        }
        self.timeout = timeout
        self.proxy = proxy
    }
}

extension APNSwiftConfiguration {
    public enum Environment {
        case production
        case sandbox
    }
}

extension APNSwiftConnection {
    public enum PushType: String {
        case alert
        case background
        case mdm
        case voip
        case fileprovider
    }
}
