# Idle stop and fullscreen result implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline. User explicitly requests implementation of both features; continue within the already authorized application/repository workflow.

**Goal:** Add configurable idle-after-scroll broadcast stopping, then show the latest screenshot fullscreen on app return with a floating Photos save button.

**Architecture:** Shared atomic capture-settings JSON feeds a monotonic idle detector. A synchronized RecordingSession owns the pipeline, detector and independent timer, so missing video callbacks cannot prevent expiry. Main app uses a durable result cursor and one modal route; fullscreen preview lazily displays source pieces using the same final crop/page plan as PNG export.

**Tech Stack:** Existing SwiftPM/SwiftUI/ReplayKit, Foundation Dispatch timer, ImageIO/CoreGraphics, XCTest and simulator UI tests. iOS 18.0 minimum; iPhone 16 Pro target. New version 0.2.0.

**Spec:** User requested arbitrary idle seconds and automatic fullscreen result on return. Default 3 seconds, any finite positive seconds (including decimals), optional disable. Arm only after actual vertical motion; ambiguous moving frames postpone stopping, static frames do not. Pause/resume resets arming. Preserve completed tail/draft and save ready before requesting ReplayKit stop. Public ReplayKit extension stop API can show a system completion message. Foregrounding request is being clarified; do not assume background auto-launch is allowed.

## Constraints / review focus

- Preserve 0.1.1 signing/group adaptation and older session decoding.
- No stopping while still switching apps, or while paused; no timer/frame write races or duplicate completion.
- One shared settings file read at broadcast start; invalid seconds never overwrite valid settings.
- Last result appears automatically once; returning again must not reopen an old dismissed result. Fresh completed work must be observed even if the app was already foreground when capture ended.
- Preview must match final outer crop and page split, use lazy cropped images, and avoid decoding the entire huge PNG.
- Save action writes actual exported PNG(s) via Photos, handles permission denial and repeated taps.
- Public repo contains synthetic test fixtures only. No signing profiles/credentials/user images.

## Task 1: Capture settings and idle lifecycle

Files: Core/CapturePreferences.swift, IdleStopDetector.swift, RecordingSession.swift, CapturePipeline.swift, Models.swift; Broadcast/SampleHandler.swift; corresponding CoreTests.
- [ ] Write settings roundtrip/validation, pre-scroll idle, arbitrary timeout, resumed scrolling, uncertainty, one-shot, disabled/reset, and no-callback watchdog tests; observe RED.
- [ ] Implement motion observations, synchronized timer/pipeline completion and optional finish reason compatible with old manifests.
- [ ] Wire Broadcast to shared preferences and public ReplayKit finish API. Run full core suite.

## Task 2: Automatic fullscreen result

Files: Core/ResultInbox.swift, StitchPlanner.swift; App/AppModel.swift, HomeView.swift, CaptureSettingsView.swift, LongScreenshotView.swift, Services.swift; Core/ThumbnailDecoder.swift.
- [ ] Write latest-ready selection and finalized-page preview tests before implementation.
- [ ] Persist cursor when opening latest result; poll only while foreground and not busy; one fullscreen presentation route for editor/result.
- [ ] Add settings controls and lazy high-resolution source-piece fullscreen viewer, close/edit controls and 54pt floating Photos save button.
- [ ] Keep returned cropped images independent of full source buffers, with serial/cancellable thumbnail decode.

## Task 3: Build / integration / delivery

Files: Tests/ScrollShotUITests, project.yml, scripts/simulator-smoke.sh, .github/workflows/build.yml, README/docs.
- [ ] Add simulator UI test for automatic fullscreen + floating save + real Photos addition using synthetic fixture. Observe baseline UI failure.
- [ ] Core and iOS jobs run independently so both RED suites are observed. Both remain required for success.
- [ ] Build 0.2.0 ARM64 IPAs, verify package structure, run unit and simulator UI tests, visually inspect screenshots.
- [ ] One independent final review, regressions for Important fixes, rerun required checks.
- [ ] Download verified IPAs and logs into outputs, archive exact source, write usage/test boundary notes and hashes. Actual phone idle timing/system finish prompt still needs user testing.
