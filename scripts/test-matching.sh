#!/bin/bash
# Run the real matcher and its XCTest cases without Apple's image frameworks.
# Useful on Linux; use `swift test` on macOS for the complete suite.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/scrollshot-matching.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/Sources/ScrollShotCore" "$scratch/Tests/ScrollShotCoreTests"
cp "$root/Core/Matching.swift" "$scratch/Sources/ScrollShotCore/"
cp "$root/Tests/ScrollShotCoreTests/MatchingTests.swift" "$scratch/Tests/ScrollShotCoreTests/"
cat > "$scratch/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ScrollShotMatching", targets: [
    .target(name: "ScrollShotCore"),
    .testTarget(name: "ScrollShotCoreTests", dependencies: ["ScrollShotCore"])
])
SWIFT
swift test --package-path "$scratch" -c release "$@"
