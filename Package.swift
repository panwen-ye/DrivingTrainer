// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DrivingTrainerCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DrivingTrainerDomain", targets: ["DrivingTrainerDomain"]),
        .library(name: "DrivingTrainerPersistence", targets: ["DrivingTrainerPersistence"]),
        .library(name: "DrivingTrainerLocationKit", targets: ["DrivingTrainerLocationKit"])
    ],
    targets: [
        .target(
            name: "DrivingTrainerDomain",
            path: "packages/Domain/Sources"
        ),
        .target(
            name: "DrivingTrainerPersistence",
            dependencies: ["DrivingTrainerDomain"],
            path: "packages/Persistence/Sources"
        ),
        .target(
            name: "DrivingTrainerLocationKit",
            dependencies: ["DrivingTrainerDomain"],
            path: "packages/LocationKit/Sources"
        ),
        .testTarget(
            name: "DrivingTrainerDomainTests",
            dependencies: ["DrivingTrainerDomain"],
            path: "tests/unit/Domain"
        ),
        .testTarget(
            name: "DrivingTrainerPersistenceTests",
            dependencies: ["DrivingTrainerDomain", "DrivingTrainerPersistence"],
            path: "tests/unit/Persistence"
        )
    ]
)
