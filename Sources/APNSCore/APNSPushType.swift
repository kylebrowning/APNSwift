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

/// A struct which represents the different supported APNs push types.
public struct APNSPushType: Hashable, Sendable, CustomStringConvertible {
    
    internal enum Configuration: String, Hashable, Sendable {
        case alert
        case background
        case location
        case voip
        case complication
        case fileprovider
        case mdm
        case liveactivity
        case pushtotalk
        case widgets
        case controls
    }
    
    public var description: String {
        configuration.rawValue
    }

    /// The underlying raw value that is send to APNs.
    internal var configuration: Configuration

    /// Use the alert push type for notifications that trigger a user interaction—for example, an alert, badge, or sound.
    ///
    /// If the notification requires immediate action from the user, set notification priority to `10`; otherwise use `5`.
    ///
    /// The alert push type is required on watchOS 6 and later. It is recommended on macOS, iOS, tvOS, and iPadOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID as the topic.
    public static let alert = Self(configuration: .alert)

    /// Use the background push type for notifications that deliver content in the background, and don’t trigger any user interactions.
    ///
    /// The background push type is required on watchOS 6 and later. It is recommended on macOS, iOS, tvOS, and iPadOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID as the topic.
    /// Always use priority `5`. Using priority `10` is an error.
    public static let background = Self(configuration: .background)

    /// Use the location push type for notifications that request a user’s location.
    ///
    /// If the location query requires an immediate response from the Location Push Service Extension, set the notification priority to `10`;
    /// otherwise, use `5`.
    ///
    /// The location push type is recommended for iOS and iPadOS. It isn’t available on macOS, tvOS, and watchOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID with `.location-query` appended to the end.
    ///
    /// - Important: The location push type supports only token-based authentication.
    public static let location = Self(configuration: .location)

    /// Use the voip push type for notifications that provide information about an incoming Voice-over-IP (VoIP) call.
    ///
    /// The voip push type is not available on watchOS. It is recommended on macOS, iOS, tvOS, and iPadOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID with `.voip` appended to the end.
    ///
    /// - Important: If you’re using certificate-based authentication, you must also register the certificate for VoIP services.
    ///  The topic is then part of the 1.2.840.113635.100.6.3.4 or 1.2.840.113635.100.6.3.6 extension.
    public static let voip = Self(configuration: .voip)

    /// Use the complication push type for notifications that contain update information for a watchOS app’s complications.
    ///
    /// The complication push type is recommended for watchOS and iOS. It is not available on macOS, tvOS, and iPadOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID with `.complication` appended to the end.
    ///
    /// - Important: If you’re using certificate-based authentication, you must also register the certificate for WatchKit services.
    ///  The topic is then part of the 1.2.840.113635.100.6.3.6 extension.
    public static let complication = Self(configuration: .complication)

    /// Use the fileprovider push type to signal changes to a File Provider extension.
    ///
    /// The fileprovider push type is not available on watchOS. It is recommended on macOS, iOS, tvOS, and iPadOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID with `.pushkit.fileprovider` appended to the end.
    public static let fileprovider = Self(configuration: .fileprovider)

    /// Use the mdm push type for notifications that tell managed devices to contact the MDM server.
    ///
    /// The mdm push type is not available on watchOS. It is recommended on macOS, iOS, tvOS, and iPadOS.
    ///
    /// - Important: If you set this push type, you must use the topic from the UID attribute in the subject of your MDM push certificate.
    public static let mdm = Self(configuration: .mdm)
    
    /// Use the live activity push type to update your live activity.
    ///
    public static let liveactivity = Self(configuration: .liveactivity)
    
    /// Use the pushtotalk push type for notifications that provide information about an incoming Push to Talk (Ptt).
    ///
    /// Push to Talk services aren’t available to compatible iPad and iPhone apps running in visionOS.
    ///
    /// - Important: If you set this push type, the topic must use your app’s bundle ID with `.voip-ptt` appended to the end.
    ///
    public static let pushtotalk = Self(configuration: .pushtotalk)

    /// Use the widgets push type for notifications that trigger widget updates.
    ///
    /// - Important: if you set this push type, the topic must use your app’s bundle ID with `.push-type.widgets` appended to the end.
    ///
    public static let widgets = Self(configuration: .widgets)

    /// Use the controls push type to reload or update a Control Center control.
    ///
    /// - Important: if you set this push type, the topic must use your app’s bundle ID with `.push-type.controls` appended to the end.
    ///
    public static let controls = Self(configuration: .controls)
}
