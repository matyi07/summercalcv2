// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SummerCal",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "SummerCal", targets: ["SummerCal"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SummerCal",
            path: ".",
            exclude: [
                "Package.swift",
                "Info.plist"
            ],
            sources: [
                "App",
                "Models",
                "Features",
                "Services",
                "Shared",
                "Storage",
                "Utilities"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
