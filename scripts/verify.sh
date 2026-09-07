#!/usr/bin/env bash
# Rasoi verification: regenerate the Xcode project, then build + test on an auto-detected
# iPhone simulator. Simulator names and runtimes drift between Xcode releases, so the
# destination is always discovered at run time — never hard-coded.
#
# Usage:
#   bash scripts/verify.sh                      # full suite (unit + UI tests)
#   bash scripts/verify.sh RasoiTests/FooTests  # one class or one test method
#   bash scripts/verify.sh --unit               # unit tests only (skips RasoiUITests)
#   bash scripts/verify.sh --build-only         # generate + build, no tests
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"
PROJECT="Rasoi.xcodeproj"
SCHEME="Rasoi"
DERIVED="$ROOT/build/DerivedData"
LOG="$ROOT/build/verify.log"
mkdir -p "$ROOT/build"

ONLY_TESTING=()
BUILD_ONLY=0
SKIP_UI=0
for arg in "$@"; do
  case "$arg" in
    --build-only) BUILD_ONLY=1 ;;
    --unit) SKIP_UI=1 ;;
    -*) echo "verify.sh: unknown flag $arg" >&2; exit 2 ;;
    *) ONLY_TESTING+=("-only-testing:$arg") ;;
  esac
done

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# ── 1. Regenerate the project from project.yml (never hand-edit the .xcodeproj) ──────────────
step "xcodegen generate"
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen not installed (brew install xcodegen)"
xcodegen generate --quiet || fail "xcodegen generate failed"

# ── 2. Pick a booted-or-available iPhone simulator with the newest runtime ────────────────────
step "detecting simulator"
DESTINATION_ID="$(
  xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys

data = json.load(sys.stdin)


def runtime_key(identifier: str):
    """Sort key from a runtime identifier such as ...SimRuntime.iOS-26-5 -> (26, 5)."""
    version = identifier.rsplit(".", 1)[-1].replace("iOS-", "")
    return tuple(int(part) for part in re.findall(r"\d+", version)) or (0,)


def device_key(name: str):
    """Prefer plain iPhone models, then bigger numbers; keeps the choice stable run to run."""
    numbers = [int(n) for n in re.findall(r"\d+", name)] or [0]
    return (0 if "Pro" not in name and "Max" not in name else 1, -numbers[0], name)


candidates = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        if not device.get("name", "").startswith("iPhone"):
            continue
        candidates.append((runtime_key(runtime), device))

if not candidates:
    sys.exit("no available iPhone simulator found")

newest = max(key for key, _ in candidates)
newest_devices = [device for key, device in candidates if key == newest]
booted = [d for d in newest_devices if d.get("state") == "Booted"]
chosen = (booted or sorted(newest_devices, key=lambda d: device_key(d["name"])))[0]
print("%s\t%s" % (chosen["udid"], chosen["name"]))
'
)" || fail "simulator detection failed"

SIM_UDID="${DESTINATION_ID%%$'\t'*}"
SIM_NAME="${DESTINATION_ID##*$'\t'}"
echo "  using: $SIM_NAME ($SIM_UDID)"
DEST="platform=iOS Simulator,id=$SIM_UDID"

# Pin the simulator to the text size and appearance a real iPhone ships with. A fresh simulator
# defaults to "medium", which is SMALLER than the iOS default of "large" — and a hit-testing bug
# that only appears at the real default once slipped through exactly that gap.
if xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1; then
  xcrun simctl ui "$SIM_UDID" content_size large >/dev/null 2>&1 || true
  xcrun simctl ui "$SIM_UDID" appearance light >/dev/null 2>&1 || true
fi

XCB=(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO)

run_xcodebuild() {
  local action_desc="$1"; shift
  if "$@" >"$LOG" 2>&1; then
    return 0
  fi

  # Xcode's build database occasionally corrupts itself ("disk I/O error", "internal
  # inconsistency error"), usually after a run was interrupted. That is not a failure of the
  # code, so wipe the derived data and try once more before reporting anything.
  if grep -qE "accessing build database|internal inconsistency error" "$LOG"; then
    echo "  build database corrupt — clearing $DERIVED and retrying once"
    rm -rf "$DERIVED"
    if "$@" >"$LOG" 2>&1; then
      return 0
    fi
  fi

  echo
  grep -E "(error:|failed|Failing tests:|\*\* [A-Z ]+ FAILED)" -A2 "$LOG" | tail -60 || true
  fail "$action_desc failed — full log: $LOG"
}

# ── 3. Build ─────────────────────────────────────────────────────────────────────────────────
step "xcodebuild build"
run_xcodebuild "build" "${XCB[@]}" build

if [[ $BUILD_ONLY -eq 1 ]]; then
  printf '\n\033[32m✓ build green (%s)\033[0m\n' "$SIM_NAME"
  exit 0
fi

# ── 4. Test ──────────────────────────────────────────────────────────────────────────────────
step "xcodebuild test"
TEST_ARGS=()
if [[ ${#ONLY_TESTING[@]} -gt 0 ]]; then
  TEST_ARGS+=("${ONLY_TESTING[@]}")
elif [[ $SKIP_UI -eq 1 ]]; then
  TEST_ARGS+=("-only-testing:RasoiTests")
fi
run_xcodebuild "tests" "${XCB[@]}" test "${TEST_ARGS[@]+"${TEST_ARGS[@]}"}"

PASSED="$(grep -cE "^Test Case .* passed" "$LOG" || true)"
printf '\n\033[32m✓ verify green — %s test case(s) passed on %s\033[0m\n' "${PASSED:-?}" "$SIM_NAME"
