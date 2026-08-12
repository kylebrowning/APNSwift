# Broadcast Channels Support

This implementation adds support for iOS 18+ broadcast push notifications to APNSwift.

## What's Implemented

### Core Types (APNSCore)

- **APNSBroadcastEnvironment**: Production and sandbox broadcast environments
- **APNSBroadcastMessageStoragePolicy**: Enum for message storage options (none or most recent)
- **APNSBroadcastChannel**: Represents a broadcast channel configuration
- **APNSBroadcastChannelList**: List of channel IDs
- **APNSBroadcastRequest**: Generic request type for all broadcast operations
- **APNSBroadcastResponse**: Generic response type
- **APNSBroadcastClientProtocol**: Protocol defining broadcast operations

### Client (APNS)

- **APNSBroadcastClient**: Full implementation with HTTP method routing for:
  - POST /channels (create)
  - GET /channels (list all)
  - GET /channels/{id} (read)
  - DELETE /channels/{id} (delete)

### Test Infrastructure (APNSTestServer)

- **APNSTestServer**: Unified real SwiftNIO HTTP server that mocks both:
  - Apple's regular push notification API (`POST /3/device/{token}`)
  - Apple's broadcast channel API (`POST/GET/DELETE /channels[/{id}]`)
  - In-memory channel storage
  - Notification recording with full metadata
  - Proper HTTP method handling
  - Error responses (404, 400)
  - Request ID generation

### Tests

- **APNSBroadcastChannelTests**: Unit tests for encoding/decoding channels (4 tests)
- **APNSBroadcastChannelListTests**: Unit tests for channel lists (3 tests)
- **APNSBroadcastClientTests**: Broadcast channel integration tests (9 tests)
- **APNSClientIntegrationTests**: Push notification integration tests (10 tests)
  - Alert, Background, VoIP, FileProvider, Complication notifications
  - Header validation, multiple notifications

## Usage Example

```swift
import APNS
import APNSCore
import Crypto

// Create a broadcast client
let client = APNSBroadcastClient(
    authenticationMethod: .jwt(
        privateKey: try P256.Signing.PrivateKey(pemRepresentation: privateKey),
        keyIdentifier: "YOUR_KEY_ID",
        teamIdentifier: "YOUR_TEAM_ID"
    ),
    environment: .production, // or .development
    eventLoopGroupProvider: .createNew,
    responseDecoder: JSONDecoder(),
    requestEncoder: JSONEncoder()
)

// Create a new broadcast channel
let channel = APNSBroadcastChannel(messageStoragePolicy: .mostRecentMessageStored)
let response = try await client.create(channel: channel, apnsRequestID: nil)
let channelID = response.body.channelID!

// Read channel info
let channelInfo = try await client.read(channelID: channelID, apnsRequestID: nil)

// List all channels
let allChannels = try await client.readAllChannelIDs(apnsRequestID: nil)
print("Channels: \\(allChannels.body.channels)")

// Delete a channel
try await client.delete(channelID: channelID, apnsRequestID: nil)

// Shutdown when done
try await client.shutdown()
```

## Testing with Mock Server

The unified `APNSTestServer` allows you to test both broadcast channels AND regular push notifications without hitting real Apple servers:

```swift
import APNSTestServer

// Start mock server on random port
let server = APNSTestServer()
try await server.start(port: 0)

// Test broadcast channels
let broadcastClient = APNSBroadcastClient(
    authenticationMethod: .jwt(...),
    environment: .custom(url: "http://127.0.0.1", port: server.port),
    eventLoopGroupProvider: .createNew,
    responseDecoder: JSONDecoder(),
    requestEncoder: JSONEncoder()
)

// Test regular push notifications
let pushClient = APNSClient(
    configuration: .init(
        authenticationMethod: .jwt(...),
        environment: .custom(url: "http://127.0.0.1", port: server.port)
    ),
    eventLoopGroupProvider: .createNew,
    responseDecoder: JSONDecoder(),
    requestEncoder: JSONEncoder()
)

// Send notifications and verify
let notification = APNSAlertNotification(...)
try await pushClient.sendAlertNotification(notification, deviceToken: "device-token")

let sent = server.getSentNotifications()
XCTAssertEqual(sent.count, 1)
XCTAssertEqual(sent[0].pushType, "alert")

// Cleanup
try await broadcastClient.shutdown()
try await pushClient.shutdown()
try await server.shutdown()
```

## Architecture Decisions

1. **Kept internal access control**: The `APNSPushType.Configuration` enum remains internal to avoid breaking the public API

2. **String-based HTTP methods**: APNSCore uses string-based HTTP methods to avoid depending on NIOHTTP1

3. **Generic request/response types**: Allows type-safe operations while maintaining flexibility

4. **Real NIO server for testing**: The mock server uses actual SwiftNIO HTTP server components for realistic testing

5. **Protocol-based client**: Allows for easy mocking and testing in consumer code

## Running Tests

```bash
# Run all tests
swift test

# Run only broadcast tests
swift test --filter Broadcast

# Run unit tests only
swift test --filter APNSBroadcastChannelTests
swift test --filter APNSBroadcastChannelListTests

# Run integration tests
swift test --filter APNSBroadcastClientTests
```

## What's Left to Do

1. **Documentation**: Add DocC documentation for all public APIs
2. **Send notifications to channels**: Implement sending push notifications to broadcast channels (separate from channel management)
3. **Error handling improvements**: Add more specific error types for broadcast operations
4. **Rate limiting**: Consider adding rate limiting for test server
5. **Swift 6 consideration**: Maintainer asked about making this Swift 6-only - decision pending

## References

- [Apple Push Notification service documentation](https://developer.apple.com/documentation/usernotifications)
- Issue: https://github.com/kylebrowning/APNSwift/issues/205
- Original WIP branch: https://github.com/eliperkins/APNSwift/tree/channels
