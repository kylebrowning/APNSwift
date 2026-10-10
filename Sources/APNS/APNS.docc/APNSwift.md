# ``APNS``

A non-blocking Swift module for sending remote Apple Push Notification requests to APNS built on AsyncHttpClient.

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

## Running as a service

With the `ServiceLifecycleSupport` trait, which is enabled by default, `APNSClient`, `APNSBroadcastClient` and `APNSClients` conform to [swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle)'s `Service`. Add a client to your `ServiceGroup` and it is shut down when the group shuts down, so you never call `shutdown()` yourself. This is how you use APNSwift from Hummingbird, Vapor 5, or any other `ServiceGroup` based app.

```swift
let serviceGroup = ServiceGroup(
    services: [app, client],
    gracefulShutdownSignals: [.sigterm],
    logger: logger
)
try await serviceGroup.run()
```

If you don't want the dependency, disable the trait and shut clients down yourself:

```swift
.package(url: "https://github.com/kylebrowning/APNSwift.git", from: "7.1.0", traits: []),
```

## Production and development clients

A device token only works against the environment the app was built for, so most servers need a production client and a development client. `APNSClients` holds a set of clients looked up by ID and registers both from one key:

```swift
let apns = APNSClients()
await apns.configure(.jwt(
    privateKey: try .init(pemRepresentation: privateKey),
    keyIdentifier: keyIdentifier,
    teamIdentifier: teamIdentifier
))

try await apns.client(.development).sendAlertNotification(notification, deviceToken: token)
try await apns.client(.production).sendAlertNotification(notification, deviceToken: token)
```

`APNSClients` is also a `Service`, so add it to your group instead of the individual clients. For custom setups, `use(_:as:)` registers a client under any ID and `default(to:)` picks which one `client` returns.

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

## Authentication
`APNSwift` provides two authentication methods. `jwt`, and `TLS`. 

**`jwt` is preferred and recommend by Apple** 
These can be configured when created your `APNSClientConfiguration`

*Notes: `jwt` requires an encrypted version of your .p8 file from Apple which comes in a `pem` format. If you're having trouble with your key being invalid please confirm it is a PEM file*
```
openssl pkcs8 -nocrypt -in /path/to/my/key.p8 -out ~/Downloads/key.pem
```

## Server Example
Take a look at [Program.swift](https://github.com/kylebrowning/APNSwift/blob/main/Sources/APNSExample/Program.swift)

## iOS Examples

For an iOS example, open the example project within this repo. 

Once inside configure your App Bundle ID and assign your development team. Build and run the ExampleApp to iOS Simulator, grab your device token, and plug it in to server example above. Background the app and run Program.swift

## Original pitch and discussion on API

* Pitch discussion: [Swift Server Forums](https://forums.swift.org/t/apple-push-notification-service-implementation-pitch/20193)
* Proposal: [SSWG-0006](https://forums.swift.org/t/feedback-nioapns-nio-based-apple-push-notification-service/24393)
* 5.0 breaking changes: [Swift Server Forums](https://forums.swift.org/t/apnswift-5-0-0-beta-release/60075/3)
