[![sswg:graduated|94x20](https://img.shields.io/badge/sswg-graduated-green.svg)](https://www.swift.org/sswg/incubation-process.html#graduation-requirements)
[![Build](https://github.com/kylebrowning/APNSwift/workflows/test/badge.svg)](https://github.com/kylebrowning/APNSwift/actions)
[![Documentation](https://img.shields.io/badge/documentation-blueviolet.svg)](https://swiftpackageindex.com/kylebrowning/APNSwift/documentation)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkylebrowning%2FAPNSwift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/kylebrowning/APNSwift)<br>
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkylebrowning%2FAPNSwift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/kylebrowning/APNSwift)
<h1> APNSwift</h1>

A non-blocking Swift module for sending remote Apple Push Notification requests to [APNS](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server) built on AsyncHttpClient.

- [Installation](#installation)
- [Getting Started](#getting-started)
- [Sending a simple notification](#sending-a-simple-notification)
- [Sending Live Activity Update](#sending-live-activity-update--end)
- [Authentication](#authentication)
- [Logging](#logging)
    - [**Background Activity Logger**](#background-activity-logger)
    - [**Notification Send Logger**](#notification-send-logger)
- [Server Example](#server-example)
- [iOS Examples](#ios-examples)
- [Original pitch and discussion on API](#original-pitch-and-discussion-on-api)

## Installation

To install `APNSwift`, just add the package as a dependency in your [**Package.swift**](https://github.com/apple/swift-package-manager/blob/master/Documentation/PackageDescriptionV4.md#dependencies).

```swift
dependencies: [
    .package(url: "https://github.com/kylebrowning/APNSwift.git", from: "7.0.0"),
]
```

## Getting Started
APNSwift aims to provide semantically correct structures to sending push notifications. You first need to setup a [`APNSClient`](https://github.com/kylebrowning/APNSwift/blob/main/Sources/APNS/APNSClient.swift). To do that youll need to know your authentication method 

```swift
let client = APNSClient(
    configuration: .init(
        authenticationMethod: .jwt(
            privateKey: try .init(pemRepresentation: privateKey),
            keyIdentifier: keyIdentifier,
            teamIdentifier: teamIdentifier
        ),
        environment: .development
    ),
    eventLoopGroupProvider: .createNew,
    responseDecoder: JSONDecoder(),
    requestEncoder: JSONEncoder()
)

// Shutdown the client when done
try await client.shutdown()
```

## Sending a simple notification
All notifications require a payload, but that payload can be empty. Payload just needs to conform to `Encodable`

```swift
struct Payload: Codable {}

try await client.sendAlertNotification(
    .init(
        alert: .init(
            title: .raw("Simple Alert"),
            subtitle: .raw("Subtitle"),
            body: .raw("Body"),
            launchImage: nil
        ),
        expiration: .immediately,
        priority: .immediately,
        topic: "com.app.bundle",
        payload: Payload()
    ),
    deviceToken: "device-token"
)
```

## Sending Live Activity Start
To successfully start a live activity:
- `Attributes` and `ContentState` must match the live activity attributes provided in `attributesType`
- `alert` must contain a title, body, and sound
    - title and body are visible to the device's paired Apple Watch when starting the live activity

```swift
let response = try await client.sendStartLiveActivityNotification(
    .init (
        expiration: .immediately,
        priority: .immediately,
        appID: "com.app.bundle",
        contentState: contentState,
        timestamp: Int(Date().timeIntervalSince1970),
        attributes: attributes,
        attributesType: "YourActivityAttributes",
        alert: .init(
            title: .raw("Your title"),
            body: .raw(Your body),
            sound: .fileName("default.aiff")
        )
    ),
    pushToStartToken: pushToStartToken
)
```

## Sending Live Activity Update / End
It requires sending `ContentState` matching with the live activity configuration to successfully update activity state. `ContentState` needs to conform to `Encodable` and `Sendable`.

```swift
try await client.sendLiveActivityNotification(
    .init(
          expiration: .immediately,
          priority: .immediately,
          appID: "com.app.bundle",
          contentState: ContentState,
          event: .update,
          timestamp: Int(Date().timeIntervalSince1970)
    ),
    deviceToken: activityPushToken
)
```

```swift
try await client.sendLiveActivityNotification(
    .init(
          expiration: .immediately,
          priority: .immediately,
          appID: "com.app.bundle",
          contentState: ContentState,
          event: .end,
          timestamp: Int(Date().timeIntervalSince1970),
          dismissalDate: .immediately // Optional to alter default behaviour
    ),
    deviceToken: activityPushToken
)
```
## Authentication
`APNSwift` provides two authentication methods. `jwt`, and `TLS`. 

**`jwt` is preferred and recommend by Apple** 
These can be configured when created your `APNSClientConfiguration`

*Notes: `jwt` requires an encrypted version of your .p8 file from Apple which comes in a `pem` format. If you're having trouble with your key being invalid please confirm it is a PEM file*
```
openssl pkcs8 -nocrypt -in /path/to/my/key.p8 -out ~/Downloads/key.pem
```

## Logging
By default APNSwift has a no-op logger which will not log anything. However if you pass a logger in, you will see logs.

There are currently two kinds of loggers.
#### **Background Activity Logger**
This logger can be passed into the `APNSClient` and will log background things like connection pooling, auth token refreshes, etc. 

#### **Notification Send Logger**
This logger can be passed into any of the `send:` methods and will log everything related to a single send request. 

## Server Example
Take a look at [Program.swift](https://github.com/kylebrowning/APNSwift/blob/main/Sources/APNSExample/Program.swift)

## iOS Example

For an iOS example, open the example project within this repo. 

Once inside configure your App Bundle ID and assign your development team. Build and run the ExampleApp to iOS Simulator, grab your device token, and plug it in to server example above. Background the app and run Program.swift

## Original pitch and discussion on API

* Pitch discussion: [Swift Server Forums](https://forums.swift.org/t/apple-push-notification-service-implementation-pitch/20193)
* Proposal: [SSWG-0006](https://forums.swift.org/t/feedback-nioapns-nio-based-apple-push-notification-service/24393)
* 5.0 breaking changes: [Swift Server Forums](https://forums.swift.org/t/apnswift-5-0-0-beta-release/60075/3)
