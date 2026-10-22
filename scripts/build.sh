#!/bin/bash
set -euo pipefail
mkdir -p build
if ! command -v xcodegen >/dev/null; then HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen; fi
swift scripts/generate-icon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
xcodegen generate
GROUP="${APP_GROUP_ID:-group.com.nizuowanzhenbang.scrollshot}"
python3 - "$GROUP" <<'PY'
import plistlib,sys
with open('build/group.entitlements','wb') as f: plistlib.dump({'com.apple.security.application-groups':[sys.argv[1]]},f)
PY
for scheme in ScrollShot; do
  mode=standard
  if ! xcodebuild -project ScrollShot.xcodeproj -scheme "$scheme" -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "build/$mode" CODE_SIGNING_ALLOWED=NO "APP_GROUP_ID=$GROUP" build >"build/$mode-build.log" 2>&1; then
    tail -100 "build/$mode-build.log"; exit 1
  fi
  staging="$(mktemp -d "$PWD/build/package.XXXXXX")"
  mkdir -p "$staging/Payload"
  cp -R "build/$mode/Build/Products/Release-iphoneos/$scheme.app" "$staging/Payload/"
  app="$staging/Payload/$scheme.app"
  codesign --force --sign - --timestamp=none --entitlements build/group.entitlements "$app/PlugIns/BroadcastExtension.appex"
  codesign --force --sign - --timestamp=none --entitlements build/group.entitlements "$app"
  codesign --verify --deep --strict "$app"
  version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Info.plist")"
  artifact="$PWD/build/ScrollShot-$mode-$version.ipa"
  (cd "$staging" && zip -qry "$artifact" Payload)
  python3 scripts/verify_ipa.py "$artifact" --mode "$mode" >"build/$mode-verification.json"
done
shasum -a 256 build/ScrollShot-standard-*.ipa >build/SHA256SUMS.txt
