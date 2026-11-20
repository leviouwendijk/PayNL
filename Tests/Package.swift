// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PayNLTests",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "t_paynl", targets: ["PayNLTests"]),
        .executable(name: "t_paynl_live", targets: ["PayNLLive"]),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "PayNLTests",
            dependencies: [.product(name: "PayNL", package: "PayNL")]
        ),
        .executableTarget(
            name: "PayNLLive",
            dependencies: [.product(name: "PayNL", package: "PayNL"), .product(name: "Milieu", package: "Milieu")]
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
