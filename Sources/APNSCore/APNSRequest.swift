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
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

public struct APNSRequest<Message: APNSMessage> {
    fileprivate final class _Storage {
        var message: Message
        var deviceToken: String
        var pushType: APNSPushType
        var expiration: APNSNotificationExpiration?
        var priority: APNSPriority?
        var apnsID: UUID?
        var topic: String?
        var collapseID: String?
        
        init(
            message: Message,
            deviceToken: String,
            pushType: APNSPushType,
            expiration: APNSNotificationExpiration?,
            priority: APNSPriority?,
            apnsID: UUID?,
            topic: String?,
            collapseID: String?
        ) {
            self.message = message
            self.deviceToken = deviceToken
            self.pushType = pushType
            self.expiration = expiration
            self.priority = priority
            self.apnsID = apnsID
            self.topic = topic
            self.collapseID = collapseID
        }
    }

    private var _storage: _Storage
    
    public var headers: [String: String] {
        var computedHeaders: [String: String] = [:]
        
        /// Push type
        computedHeaders["apns-push-type"] = pushType.configuration.rawValue

        /// APNS ID
        if let apnsID = apnsID {
            computedHeaders["apns-id"] = apnsID.uuidString.lowercased()
        }

        /// Expiration
        if let expiration = expiration?.expiration {
            computedHeaders["apns-expiration"] = "\(expiration)"
        }

        /// Priority
        if let priority = priority?.rawValue {
            computedHeaders["apns-priority"] = "\(priority)"
        }

        /// Topic
        if let topic = topic {
            computedHeaders["apns-topic"] = topic
        }

        /// Collapse ID
        if let collapseID = collapseID {
            computedHeaders["apns-collapse-id"] = collapseID
        }
        
        return computedHeaders
    }
    public init(
        message: Message,
        deviceToken: String,
        pushType: APNSPushType,
        expiration: APNSNotificationExpiration?,
        priority: APNSPriority?,
        apnsID: UUID?,
        topic: String?,
        collapseID: String?
    ) {
        self._storage = _Storage(
            message: message,
            deviceToken: deviceToken,
            pushType: pushType,
            expiration: expiration,
            priority: priority,
            apnsID: apnsID,
            topic: topic,
            collapseID: collapseID
        )
    }
}

extension APNSRequest._Storage {
    func copy() -> APNSRequest._Storage {
        APNSRequest._Storage(
            message: message,
            deviceToken: deviceToken,
            pushType: pushType,
            expiration: expiration,
            priority: priority,
            apnsID: apnsID,
            topic: topic,
            collapseID: collapseID
        )
    }
}

extension APNSRequest {
    
    public var message: Message {
        get {
            return self._storage.message
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.message = newValue
        }
    }

    public var deviceToken: String {
        get {
            return self._storage.deviceToken
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.deviceToken = newValue
        }
    }
    
    public var pushType: APNSPushType {
        get {
            return self._storage.pushType
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.pushType = newValue
        }
    }
    
    public var expiration: APNSNotificationExpiration? {
        get {
            return self._storage.expiration
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.expiration = newValue
        }
    }
    
    public var priority: APNSPriority? {
        get {
            return self._storage.priority
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.priority = newValue
        }
    }
    
    public var apnsID: UUID? {
        get {
            return self._storage.apnsID
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.apnsID = newValue
        }
    }
    
    public var topic: String? {
        get {
            return self._storage.topic
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.topic = newValue
        }
    }
    
    public var collapseID: String? {
        get {
            return self._storage.collapseID
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.collapseID = newValue
        }
    }
}
