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

#if canImport(FoundationEssentials)
import struct FoundationEssentials.Date
import struct FoundationEssentials.UUID
#else
import struct Foundation.Date
import struct Foundation.UUID
#endif

/// An error returned by APNs.
public struct APNSError: Error {
    
    /// The error reason returned by APNs.
    ///
    /// For more information please look here: [Reference]( https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/handling_notification_responses_from_apns)
    public struct ErrorReason: Hashable, Sendable {
        public enum Reason: RawRepresentable, Hashable, Sendable {
            public typealias RawValue = String

            case badCollapseIdentifier
            case badDeviceToken
            case badExpirationDate
            case badMessageId
            case badPriority
            case badTopic
            case deviceTokenNotForTopic
            case duplicateHeaders
            case idleTimeout
            case invalidPushType
            case missingDeviceToken
            case missingTopic
            case payloadEmpty
            case topicDisallowed
            case badCertificate
            case badCertificateEnvironment
            case expiredProviderToken
            case forbidden
            case invalidProviderToken
            case missingProviderToken
            case unrelatedKeyIdInToken
            case badEnvironmentKeyIdInToken
            case badPath
            case methodNotAllowed
            case expiredToken
            case unregistered
            case payloadTooLarge
            case tooManyProviderTokenUpdates
            case tooManyRequests
            case internalServerError
            case serviceUnavailable
            case shutdown
            case badEnvironmentKeyInToken
            case unknown(String)
            
            public init(rawValue: RawValue) {
                switch rawValue {
                case "BadCollapseId":
                    self = .badCollapseIdentifier
                case "BadDeviceToken":
                    self = .badDeviceToken
                case "BadExpirationDate":
                    self = .badExpirationDate
                case "BadMessageId":
                    self = .badMessageId
                case "BadPriority":
                    self = .badPriority
                case "BadTopic":
                    self = .badTopic
                case "DeviceTokenNotForTopic":
                    self = .deviceTokenNotForTopic
                case "DuplicateHeaders":
                    self = .duplicateHeaders
                case "IdleTimeout":
                    self = .idleTimeout
                case "InvalidPushType":
                    self = .invalidPushType
                case "MissingDeviceToken":
                    self = .missingDeviceToken
                case "MissingTopic":
                    self = .missingTopic
                case "PayloadEmpty":
                    self = .payloadEmpty
                case "TopicDisallowed":
                    self = .topicDisallowed
                case "BadCertificate":
                    self = .badCertificate
                case "BadCertificateEnvironment":
                    self = .badCertificateEnvironment
                case "ExpiredProviderToken":
                    self = .expiredProviderToken
                case "Forbidden":
                    self = .forbidden
                case "InvalidProviderToken":
                    self = .invalidProviderToken
                case "MissingProviderToken":
                    self = .missingProviderToken
                case "UnrelatedKeyIdInToken":
                    self = .unrelatedKeyIdInToken
                case "BadEnvironmentKeyIdInToken":
                    self = .badEnvironmentKeyIdInToken
                case "BadPath":
                    self = .badPath
                case "MethodNotAllowed":
                    self = .methodNotAllowed
                case "ExpiredToken":
                    self = .expiredToken
                case "Unregistered":
                    self = .unregistered
                case "PayloadTooLarge":
                    self = .payloadTooLarge
                case "TooManyProviderTokenUpdates":
                    self = .tooManyProviderTokenUpdates
                case "TooManyRequests":
                    self = .tooManyRequests
                case "InternalServerError":
                    self = .internalServerError
                case "ServiceUnavailable":
                    self = .serviceUnavailable
                case "Shutdown":
                    self = .shutdown
                case "BadEnvironmentKeyInToken":
                    self = .badEnvironmentKeyInToken
                default:
                    self = .unknown(rawValue)
                }
            }

            public var rawValue: RawValue {
                switch self {
                case .badCollapseIdentifier:
                    return "BadCollapseId"
                case .badDeviceToken:
                    return "BadDeviceToken"
                case .badExpirationDate:
                    return "BadExpirationDate"
                case .badMessageId:
                    return "BadMessageId"
                case .badPriority:
                    return "BadPriority"
                case .badTopic:
                    return "BadTopic"
                case .deviceTokenNotForTopic:
                    return "DeviceTokenNotForTopic"
                case .duplicateHeaders:
                    return "DuplicateHeaders"
                case .idleTimeout:
                    return "IdleTimeout"
                case .invalidPushType:
                    return "InvalidPushType"
                case .missingDeviceToken:
                    return "MissingDeviceToken"
                case .missingTopic:
                    return "MissingTopic"
                case .payloadEmpty:
                    return "PayloadEmpty"
                case .topicDisallowed:
                    return "TopicDisallowed"
                case .badCertificate:
                    return "BadCertificate"
                case .badCertificateEnvironment:
                    return "BadCertificateEnvironment"
                case .expiredProviderToken:
                    return "ExpiredProviderToken"
                case .forbidden:
                    return "Forbidden"
                case .invalidProviderToken:
                    return "InvalidProviderToken"
                case .missingProviderToken:
                    return "MissingProviderToken"
                case .unrelatedKeyIdInToken:
                    return "UnrelatedKeyIdInToken"
                case .badEnvironmentKeyIdInToken:
                    return "BadEnvironmentKeyIdInToken"
                case .badPath:
                    return "BadPath"
                case .methodNotAllowed:
                    return "MethodNotAllowed"
                case .expiredToken:
                    return "ExpiredToken"
                case .unregistered:
                    return "Unregistered"
                case .payloadTooLarge:
                    return "PayloadTooLarge"
                case .tooManyProviderTokenUpdates:
                    return "TooManyProviderTokenUpdates"
                case .tooManyRequests:
                    return "TooManyRequests"
                case .internalServerError:
                    return "InternalServerError"
                case .serviceUnavailable:
                    return "ServiceUnavailable"
                case .shutdown:
                    return "Shutdown"
                case .badEnvironmentKeyInToken:
                    return "BadEnvironmentKeyInToken"
                case .unknown(let string):
                    return string
                }
            }

            public var errorDescription: String {
                switch self {
                case .badCollapseIdentifier:
                    return "The collapse identifier exceeds the maximum allowed size"
                case .badDeviceToken:
                    return "The specified device token was bad. Verify that the request contains a valid token and that the token matches the environment"
                case .badExpirationDate:
                    return "The expiration value is bad"
                case .badMessageId:
                    return "The apns-id value is bad"
                case .badPriority:
                    return "The apns-priority value is bad"
                case .badTopic:
                    return "The apns-topic was invalid"
                case .deviceTokenNotForTopic:
                    return "The device token does not match the specified topic"
                case .duplicateHeaders:
                    return "One or more headers were repeated"
                case .idleTimeout:
                    return "Idle time out"
                case .invalidPushType:
                    return "The apns-push-type value is invalid"
                case .missingDeviceToken:
                    return "The device token is not specified in the request :path. Verify that the :path header contains the device token"
                case .missingTopic:
                    return "The apns-topic header of the request was not specified and was required. The apns-topic header is mandatory when the client is connected using a certificate that supports multiple topics"
                case .payloadEmpty:
                    return "The message payload was empty"
                case .topicDisallowed:
                    return "Pushing to this topic is not allowed"
                case .badCertificate:
                    return "The certificate was bad"
                case .badCertificateEnvironment:
                    return "The client certificate was for the wrong environment"
                case .expiredProviderToken:
                    return "The provider token is stale and a new token should be generated"
                case .forbidden:
                    return "The specified action is not allowed"
                case .invalidProviderToken:
                    return "The provider token is not valid or the token signature could not be verified"
                case .missingProviderToken:
                    return "No provider certificate was used to connect to APNs and Authorization header was missing or no provider token was specified"
                case .unrelatedKeyIdInToken:
                    return "The key ID in the provider token isn't related to the key ID of the token used in the first push of this connection. To use this token, open a new connection"
                case .badEnvironmentKeyIdInToken:
                    return "The key ID in the provider token doesn't match the environment"
                case .badPath:
                    return "The request contained a bad :path value"
                case .methodNotAllowed:
                    return "The specified :method was not POST"
                case .expiredToken:
                    return "The device token has expired"
                case .unregistered:
                    return "The device token is inactive for the specified topic. There is no need to send further pushes to the same device token, unless your application retrieves the same device token"
                case .payloadTooLarge:
                    return "The message payload was too large"
                case .tooManyProviderTokenUpdates:
                    return "The provider’s authentication token is being updated too often. Update the authentication token no more than once every 20 minutes"
                case .tooManyRequests:
                    return "Too many requests were made consecutively to the same device token"
                case .internalServerError:
                    return "An internal server error occurred"
                case .serviceUnavailable:
                    return "The service is unavailable"
                case .shutdown:
                    return "The server is shutting down"
                case .badEnvironmentKeyInToken:
                    return "Environment mismatch between key and APNs endpoint"
                case .unknown(let string):
                    return "Indicates an error reason that is unknown value \"\(string)\" to `APNSwift`. If you receive this please file an issue so that we can extend the known error reasons"
                }
            }
        }

        internal var _reason: Reason

        /// The error string received from APNs.
        public var reason: String {
            self._reason.rawValue
        }

        /// A detailed description of the error.
        public var errorDescription: String {
            self._reason.errorDescription
        }

        public static var badCollapseIdentifier: Self {
            return .init(_reason: .badCollapseIdentifier)
        }

        public static var badDeviceToken: Self {
            return .init(_reason: .badDeviceToken)
        }

        public static var badExpirationDate: Self {
            return .init(_reason: .badExpirationDate)
        }

        public static var badMessageId: Self {
            return .init(_reason: .badMessageId)
        }

        public static var badPriority: Self {
            return .init(_reason: .badPriority)
        }

        public static var badTopic: Self {
            return .init(_reason: .badTopic)
        }

        public static var deviceTokenNotForTopic: Self {
            return .init(_reason: .deviceTokenNotForTopic)
        }

        public static var duplicateHeaders: Self {
            return .init(_reason: .duplicateHeaders)
        }

        public static var idleTimeout: Self {
            return .init(_reason: .idleTimeout)
        }

        public static var invalidPushType: Self {
            return .init(_reason: .invalidPushType)
        }

        public static var missingDeviceToken: Self {
            return .init(_reason: .missingDeviceToken)
        }

        public static var missingTopic: Self {
            return .init(_reason: .missingTopic)
        }

        public static var payloadEmpty: Self {
            return .init(_reason: .payloadEmpty)
        }

        public static var topicDisallowed: Self {
            return .init(_reason: .topicDisallowed)
        }

        public static var badCertificate: Self {
            return .init(_reason: .badCertificate)
        }

        public static var badCertificateEnvironment: Self {
            return .init(_reason: .badCertificateEnvironment)
        }

        public static var expiredProviderToken: Self {
            return .init(_reason: .expiredProviderToken)
        }

        public static var forbidden: Self {
            return .init(_reason: .forbidden)
        }

        public static var invalidProviderToken: Self {
            return .init(_reason: .invalidProviderToken)
        }

        public static var missingProviderToken: Self {
            return .init(_reason: .missingProviderToken)
        }

        public static var unrelatedKeyIdInToken: Self {
            return .init(_reason: .unrelatedKeyIdInToken)
        }

        public static var badEnvironmentKeyIdInToken: Self {
            return .init(_reason: .badEnvironmentKeyIdInToken)
        }

        public static var badPath: Self {
            return .init(_reason: .badPath)
        }

        public static var methodNotAllowed: Self {
            return .init(_reason: .methodNotAllowed)
        }

        public static var expiredToken: Self {
            return .init(_reason: .expiredToken)
        }

        public static var unregistered: Self {
            return .init(_reason: .unregistered)
        }

        public static var payloadTooLarge: Self {
            return .init(_reason: .payloadTooLarge)
        }

        public static var tooManyProviderTokenUpdates: Self {
            return .init(_reason: .tooManyProviderTokenUpdates)
        }

        public static var tooManyRequests: Self {
            return .init(_reason: .tooManyRequests)
        }

        public static var internalServerError: Self {
            return .init(_reason: .internalServerError)
        }

        public static var serviceUnavailable: Self {
            return .init(_reason: .serviceUnavailable)
        }

        public static var shutdown: Self {
            return .init(_reason: .shutdown)
        }

        public static var badEnvironmentKeyInToken: Self {
            return .init(_reason: .badEnvironmentKeyInToken)
        }

        init(_reason: APNSError.ErrorReason.Reason) {
            self._reason = _reason
        }
    }

    /// The HTTP status code.
    public let responseStatus: Int

    /// The same value as the `apnsID` send in the request.
    ///
    /// Use this value to identify the notification. If you don’t specify an `apnsID` in your request,
    /// APNs creates a new `UUID` and returns it in this header.
    public let apnsID: UUID?
    
    /// A unique ID for the notification used for development, as determined by the APNs servers.
    ///
    /// In the development or sandbox environement, this value can be used to look up information about notifications on the [Push Notifications Console](https://icloud.developer.apple.com/dashboard/notifications). This value is not provided in the production environement.
    public var apnsUniqueID: UUID?

    /// The error code indicating the reason for the failure.
    public let reason: ErrorReason?

    /// The date at which APNs confirmed the token was no longer valid for the topic.
    ///
    /// This is only set when the error reason is `unregistered`.
    public let timestamp: Date?
    
    public init(
        responseStatus: Int,
        apnsID: UUID? = nil,
        apnsUniqueID: UUID? = nil,
        apnsResponse: APNSErrorResponse? = nil,
        timestamp: Date? = nil
    ) {
        self.responseStatus = responseStatus
        self.apnsID = apnsID
        self.apnsUniqueID = apnsUniqueID
        if let apnsResponse {
            self.reason = .init(_reason: .init(rawValue: apnsResponse.reason))
        } else {
            self.reason = nil
        }
        
        self.timestamp = timestamp
    }
}

extension APNSError: Hashable {
    public static func == (lhs: APNSError, rhs: APNSError) -> Bool {
        return
            lhs.responseStatus == rhs.responseStatus &&
            lhs.apnsID == rhs.apnsID &&
            lhs.apnsUniqueID == rhs.apnsUniqueID &&
            lhs.reason == rhs.reason &&
            lhs.timestamp == rhs.timestamp
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.responseStatus)
        hasher.combine(self.apnsID)
        hasher.combine(self.apnsUniqueID)
        hasher.combine(self.reason)
        hasher.combine(self.timestamp)
    }
}
