// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "GuidelinesCLI",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "guidelines",
            targets: [
                "GuidelinesCLI",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Guidelines.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Terminal.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Fuzzy.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Matching.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Ranking.git",
            branch: "master"
        ),
    ],
    targets: [
        .executableTarget(
            name: "GuidelinesCLI",
            dependencies: [
                .product(
                    name: "Guidelines",
                    package: "Guidelines"
                ),
                .product(
                    name: "Terminal",
                    package: "Terminal"
                ),
                .product(
                    name: "Fuzzy",
                    package: "Fuzzy"
                ),
                .product(
                    name: "Matching",
                    package: "Matching"
                ),
                .product(
                    name: "Ranking",
                    package: "Ranking"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
