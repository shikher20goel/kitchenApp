#!/usr/bin/env bash
# Switch Rasoi between simulator-only signing and real-device signing.
#
#   bash scripts/configure-signing.sh none
#       Simulator/CI mode (the committed default): clears DEVELOPMENT_TEAM. Simulator builds
#       pass CODE_SIGNING_ALLOWED=NO on the command line (see scripts/verify.sh).
#
#   bash scripts/configure-signing.sh free <TEAM_ID> [bundle-id]
#       Free Apple personal team. Automatic signing with your personal team; app expires after
#       7 days and must be re-installed (see HANDOFF.md). Pass a custom bundle id if the default
#       is already taken in your account.
#
#   bash scripts/configure-signing.sh full <TEAM_ID> [bundle-id]
#       Paid Apple Developer Program team. Same automatic signing, 1-year provisioning, and the
#       hook for Phase 2 capabilities (CloudKit, widgets). v1 declares no entitlements at all,
#       so today `full` differs from `free` only in the reminder it prints.
#
# The script only ever edits project.yml, then regenerates the project with XcodeGen.
# It never touches the .xcodeproj by hand and never stores the team id anywhere but project.yml.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
YML="project.yml"
MODE="${1:-}"
TEAM_ID="${2:-}"
BUNDLE_ID="${3:-com.shikhergoel.rasoi}"

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

[[ -f "$YML" ]] || { echo "configure-signing.sh: $YML not found" >&2; exit 1; }

case "$MODE" in
  none) ;;
  free|full)
    [[ -n "$TEAM_ID" ]] || { echo "configure-signing.sh: $MODE mode needs a TEAM_ID" >&2; usage; }
    [[ "$TEAM_ID" =~ ^[A-Z0-9]{6,12}$ ]] || {
      echo "configure-signing.sh: '$TEAM_ID' does not look like an Apple team id (6-12 chars, A-Z0-9)" >&2
      exit 1
    }
    ;;
  *) usage ;;
esac

TEAM_ID="$TEAM_ID" BUNDLE_ID="$BUNDLE_ID" MODE="$MODE" /usr/bin/python3 - "$YML" <<'PY'
import os
import re
import sys

path = sys.argv[1]
mode = os.environ["MODE"]
team = os.environ["TEAM_ID"]
bundle = os.environ["BUNDLE_ID"]
text = open(path).read()

# Project-wide team. This is the ONLY line `free`/`full` change in project.yml; per-target
# code-signing switches are deliberately absent from project.yml so simulator builds pass
# CODE_SIGNING_ALLOWED=NO on the command line (verify.sh) and device builds sign automatically
# with the team set here plus -allowProvisioningUpdates.
text = re.sub(r'(?m)^(\s*DEVELOPMENT_TEAM:).*$', r'\1 "%s"' % team, text)

# App bundle id (test bundles derive from it).
text = re.sub(
    r'(?m)^(\s*PRODUCT_BUNDLE_IDENTIFIER:\s*)com\.[A-Za-z0-9._-]*rasoi$',
    lambda m: m.group(1) + bundle,
    text,
)
text = re.sub(
    r'(?m)^(\s*PRODUCT_BUNDLE_IDENTIFIER:\s*)com\.[A-Za-z0-9._-]*rasoi\.(tests|uitests)$',
    lambda m: "%s%s.%s" % (m.group(1), bundle, m.group(2)),
    text,
)

open(path, "w").write(text)
PY

command -v xcodegen >/dev/null 2>&1 || { echo "configure-signing.sh: xcodegen not installed (brew install xcodegen)" >&2; exit 1; }
xcodegen generate --quiet

case "$MODE" in
  none) echo "✓ signing disabled (simulator / CI mode); project regenerated" ;;
  free) cat <<EOF
✓ free personal-team signing configured
  team:   $TEAM_ID
  bundle: $BUNDLE_ID
Next (device must be plugged in, Developer Mode on):
  xcodebuild -project Rasoi.xcodeproj -scheme Rasoi -configuration Debug \\
    -destination 'generic/platform=iOS' -allowProvisioningUpdates \\
    -derivedDataPath build/DerivedData build
  xcrun devicectl device install app --device <DEVICE_UDID> \\
    build/DerivedData/Build/Products/Debug-iphoneos/Rasoi.app
Reminder: a free personal team expires the build after 7 days — repeat to refresh.
EOF
  ;;
  full) cat <<EOF
✓ paid-team signing configured
  team:   $TEAM_ID
  bundle: $BUNDLE_ID
v1 declares no entitlements — nothing else to configure. Phase 2 capabilities (CloudKit,
widgets, push) would be added to project.yml here, never to the .xcodeproj by hand.
EOF
  ;;
esac
