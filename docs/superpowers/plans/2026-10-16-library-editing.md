# Library, settings and image tools implementation plan

> Execute inline using executing-plans; one fresh final reviewer. User explicitly requested the implementation within the existing app and authorized public-source/free standard macOS CI workflow.

**Goal:** Deliver 0.3.0 with library-first home, leading/right swipe deletion, newest-five + all drafts, settings/theme, rectangle mosaic/crop, compression confirmation above configurable20MB, smart scrollbar removal toggle and start/stop vibration requests.

**Architecture:** Preserve source frames. Optional backward-compatible manifest metadata stores per-page pixel crop/redaction edits, exact rendered preview tiles and compressed copies. Shared strip export produces final PNG and bounded preview tiles together. JPEG compression composes those tiles into bounded-height pages; commit only if smaller and keep originals. UI settings use shared capture JSON for export/capture preferences and app-local appearance. Broadcast lifecycle uses a one-shot feedback gate and public AudioToolbox vibration API, with actual background behavior requiring physical validation.

**Design decisions:** Existing library/capture/editor flow is extended, not replaced. Default compression prompt20MiB and editable positive MB; default theme system/light/dark; capture switches and diagnostics move into settings. Library rows support leading swipe because user explicitly requested right-swipe; archive lists all sessions. Delete refuses live recording/paused sessions and global operations; a confirmation prevents accidental destructive removal. Mosaic selection works over source tiles; crop supports rectangle selection and numeric edges. Image edits apply only to generated pages and can be reset from original frames. Smart scrollbar detection is conservative, handles narrow high-contrast bars near the right edge, changes detected pixels only and is switchable. No forced foreground/background audio keepalive/private APIs.

**Constraints:** Preserve0.2 signing adaptation and all old drafts; iOS18.0 minimum; real image/output tests; no original IPA/profile/user media publication. Background haptics and iOS18.7.8 performance cannot be established by simulator tests.

- [ ] Add RED tests: real cropped/mosaicked output pixels, bounded tiles, scrollbar detection/unchanged neighbors, safe delete, preference backward compatibility, smaller bounded JPEG copies/retained original; UI settings/archive/delete and prior fullscreen/save regression.
- [ ] Implement core raster/export/compression and conservative scrollbar cleaner; run required tests.
- [ ] Move library to top, five previews/all archive, leading swipe confirmation; settings/theme/capture options; lifecycle vibration.
- [ ] Add tiled image editing, crop controls and rectangle mosaics; large-save confirmation/manual compression.
- [ ] Independent final review, fix Important findings with regressions; build both IPAs, simulator UI/visual verification.
- [ ] Deliver verified0.3.0 IPAs, exact source, instructions, test evidence and hashes. Preserve older packages.
