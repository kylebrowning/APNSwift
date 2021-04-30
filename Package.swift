// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "apnswift",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "APNSwiftExample", targets: ["APNSwiftExample"]),
        .library(name: "APNSwift", targets: ["APNSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.10.1"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.13.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.2.5"),
    ],
    targets: [
        .target(name: "APNSwiftExample", dependencies: [
            .target(name: "APNSwift"),
        ]),
        .target(name: "APNSwiftPemExample", dependencies: [
            .target(name: "APNSwift"),
        ]),
        .testTarget(name: "APNSwiftTests", dependencies: [
            .target(name: "APNSwift"),
        ]),
        .target(name: "APNSwift", dependencies: [
            .product(name: "JWTKit", package: "jwt-kit"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOHTTP2", package: "swift-nio-http2"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
            .product(name: "NIOTLS", package: "swift-nio"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
    ]
)
