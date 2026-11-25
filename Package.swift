// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PayNL",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "PayNL", targets: ["PayNL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/swift-webc/HTTP.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Sensitivity.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "PayNL",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "HTTP", package: "HTTP"),
                .product(name: "Sensitivity", package: "Sensitivity"),
            ],
            path: "Sources/PayNL"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []
        settings.append(.treatAllWarnings(as: .error))
        settings.append(.unsafeFlags(["-continue-building-after-errors"]))
        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
