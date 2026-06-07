// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "riscv-swift",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        // RISC-V ISA simulator core: Swift replica of the F# reference (riscv-fs).
        .target(
            name: "RISCV"
        ),
        // Thin CLI entry point; all application logic lives (testable) in RISCV.Program.
        .executableTarget(
            name: "riscv-swift",
            dependencies: ["RISCV"]
        ),
        // Performance benchmarks for every implemented ISA (see scripts/bench-ci.sh and
        // .github/workflows/bench.yaml). Run: swift run -c release riscv-bench [--ci]
        .executableTarget(
            name: "riscv-bench",
            dependencies: ["RISCV"]
        ),
        .testTarget(
            name: "RISCVTests",
            dependencies: ["RISCV"]
        ),
        .testTarget(
          name: "RISCVTests",
           dependencies: ["riscv-swift"]),
    ]
)
