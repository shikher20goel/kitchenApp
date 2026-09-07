#!/usr/bin/env bash
# Smoke-runs Rasoi in the simulator and collects a screenshot of every screen (task 065).
#
#   bash scripts/screenshots.sh
#
# The UI test drives the app and writes PNGs into the test runner's container; this script copies
# them out of the simulator into docs/screenshots/. Only demo household data is ever used.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"
OUT="$ROOT/docs/screenshots"
DERIVED="$ROOT/build/DerivedData"
LOG="$ROOT/build/screenshots.log"
RUNNER_BUNDLE_ID="com.shikhergoel.rasoi.uitests.xctrunner"
mkdir -p "$OUT" "$ROOT/build"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

step "xcodegen generate"
xcodegen generate --quiet

step "detecting simulator"
SIM="$(xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys
data = json.load(sys.stdin)
def runtime_key(identifier):
    version = identifier.rsplit(".", 1)[-1].replace("iOS-", "")
    return tuple(int(p) for p in re.findall(r"\d+", version)) or (0,)
def device_key(name):
    numbers = [int(n) for n in re.findall(r"\d+", name)] or [0]
    return (0 if "Pro" not in name and "Max" not in name else 1, -numbers[0], name)
candidates = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            candidates.append((runtime_key(runtime), device))
if not candidates:
    sys.exit("no available iPhone simulator found")
newest = max(k for k, _ in candidates)
newest_devices = [d for k, d in candidates if k == newest]
booted = [d for d in newest_devices if d.get("state") == "Booted"]
chosen = (booted or sorted(newest_devices, key=lambda d: device_key(d["name"])))[0]
print("%s\t%s" % (chosen["udid"], chosen["name"]))
')" || fail "simulator detection failed"
UDID="${SIM%%$'\t'*}"
NAME="${SIM##*$'\t'}"
echo "  using: $NAME ($UDID)"

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
xcrun simctl ui "$UDID" content_size large >/dev/null 2>&1 || true
xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1 || true

step "running the screenshot walk-through"
if ! xcodebuild -project Rasoi.xcodeproj -scheme Rasoi \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    -only-testing:RasoiUITests/ScreenshotUITests test >"$LOG" 2>&1; then
  grep -E "(error:|Failing tests:)" -A2 "$LOG" | tail -40 || true
  fail "the screenshot run failed — full log: $LOG"
fi

step "collecting the images"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$RUNNER_BUNDLE_ID" data 2>/dev/null || true)"
[[ -n "$CONTAINER" ]] || fail "could not find the test runner's container ($RUNNER_BUNDLE_ID)"
COPIED=0
for file in "$CONTAINER"/Documents/*.png; do
  [[ -e "$file" ]] || continue
  cp "$file" "$OUT/"
  COPIED=$((COPIED + 1))
done
[[ $COPIED -gt 0 ]] || fail "no screenshots were produced"

printf '\n\033[32m✓ %d screenshots in %s\033[0m\n' "$COPIED" "$OUT"
ls -1 "$OUT"
