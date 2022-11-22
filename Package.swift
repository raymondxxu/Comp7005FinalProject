// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Proxy",
    dependencies: [
        .package(url: "https://github.com/raymondxxu/Comp7005FinalProjectCommonLib", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Proxy",
            dependencies: [
                .product(name: "CommonLib", package: "Comp7005FinalProjectCommonLib")
            ]),
        .testTarget(
            name: "ProxyTests",
            dependencies: ["Proxy"]),
    ]
)
