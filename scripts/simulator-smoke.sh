#!/bin/bash
set -euo pipefail
if ! xcodebuild -project ScrollShot.xcodeproj -scheme ScrollShotImport -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/simulator CODE_SIGNING_ALLOWED=NO build >build/simulator-build.log 2>&1; then tail -80 build/simulator-build.log; exit 1; fi
xcrun simctl list devices available -j >build/devices.json
python3 - <<'PY'
import json
data=json.load(open('build/devices.json'))
devices=[dict(d,runtime=r) for r,ds in data['devices'].items() for d in ds if 'iPhone' in d['name'] and d.get('isAvailable')]
devices.sort(key=lambda d: (d['name']!='iPhone 16 Pro', '18-5' not in d['runtime']))
if not devices: raise SystemExit('No available iPhone simulator')
json.dump(devices[0],open('build/simulator-device.json','w'),indent=2)
PY
udid="$(python3 -c 'import json;print(json.load(open("build/simulator-device.json"))["udid"])')"
state="$(python3 -c 'import json;print(json.load(open("build/simulator-device.json"))["state"])')"
if [ "$state" != Booted ]; then xcrun simctl boot "$udid"; fi
xcrun simctl bootstatus "$udid" -b
bundle=com.nizuowanzhenbang.scrollshot.import
xcrun simctl install "$udid" build/simulator/Build/Products/Debug-iphonesimulator/ScrollShotImport.app
xcrun simctl launch "$udid" "$bundle" | tee build/simulator-launch.log
sleep 3
xcrun simctl io "$udid" screenshot build/home-screen.png
xcrun simctl terminate "$udid" "$bundle"
container="$(xcrun simctl get_app_container "$udid" "$bundle" data)"
swift run FixtureGenerator "$container/Documents/Drafts" >build/fixture-session.txt
xcrun simctl launch "$udid" "$bundle" | tee -a build/simulator-launch.log
python3 - "$container/Documents/Drafts" <<'PY'
import pathlib,json,time,sys,struct
root=pathlib.Path(sys.argv[1])
for _ in range(45):
    for p in root.glob('*/session.json'):
        m=json.loads(p.read_bytes())
        if m.get('outputs'):
            png=p.parent/m['outputs'][0];raw=png.read_bytes()
            w,h=struct.unpack_from('>II',raw,16)
            assert (w,h)==(128,680),(w,h)
            json.dump({'result':'PASS','fixture':'synthetic 3-frame vertical scroll','width':w,'height':h,'outputs':len(m['outputs']),'device_test':'simulator only'},open('build/simulator-smoke.json','w'),indent=2)
            sys.exit(0)
    time.sleep(1)
raise SystemExit('Application did not export the synthetic fixture')
PY
xcrun simctl io "$udid" screenshot build/editor-screen.png

# A second unseen fixture pins the automatic presentation and real save flow.
xcrun simctl terminate "$udid" "$bundle"
swift run FixtureGenerator "$container/Documents/Drafts" >build/fixture-ui-session.txt
xcrun simctl privacy grant "$udid" photos-add "$bundle"
if ! xcodebuild test -project ScrollShot.xcodeproj -scheme ScrollShotImport -destination "id=$udid" -derivedDataPath build/simulator -resultBundlePath build/ui-tests.xcresult -parallel-testing-enabled NO -only-testing:ScrollShotUITests/ResultFlowTests CODE_SIGNING_ALLOWED=NO >build/ui-test.log 2>&1; then tail -70 build/ui-test.log; exit 1; fi
