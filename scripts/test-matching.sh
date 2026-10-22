#!/bin/bash
# Run real matching, seam selection and planning tests without Apple frameworks.
# Useful on Linux; use `swift test` on macOS for the complete suite.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/scrollshot-matching.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/Sources/ScrollShotCore" "$scratch/Tests/ScrollShotCoreTests"
cp "$root/Core/Matching.swift" "$scratch/Sources/ScrollShotCore/"
cp "$root/Core/SeamSelector.swift" "$scratch/Sources/ScrollShotCore/"
cp "$root/Core/Models.swift" "$root/Core/StitchPlanner.swift" "$root/Core/ImageGeometry.swift" "$scratch/Sources/ScrollShotCore/"
cp "$root/Tests/ScrollShotCoreTests/MatchingTests.swift" "$scratch/Tests/ScrollShotCoreTests/"
cp "$root/Tests/ScrollShotCoreTests/PlannerTests.swift" "$scratch/Tests/ScrollShotCoreTests/"
cp "$root/Tests/ScrollShotCoreTests/SeamTests.swift" "$scratch/Tests/ScrollShotCoreTests/"
cat > "$scratch/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ScrollShotMatching", targets: [
    .target(name: "ScrollShotCore"),
    .testTarget(name: "ScrollShotCoreTests", dependencies: ["ScrollShotCore"])
])
SWIFT
swift test --package-path "$scratch" -c release "$@"
