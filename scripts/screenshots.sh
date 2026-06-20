#!/usr/bin/env bash
# Render the app's surfaces to docs/screenshots/ via the ScreenshotTests render
# pass, then extract the attachments from the result bundle. Run `just bootstrap`
# first. Usage: scripts/screenshots.sh ["iPhone 17 Pro"]
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${1:-iPhone 17 Pro}"
RESULT="$(mktemp -d)/shots.xcresult"
EXPORT="$(mktemp -d)"

echo "Rendering screenshots on ${SIM}..."
xcodebuild test \
  -project Inward.xcodeproj -scheme Inward \
  -destination "platform=iOS Simulator,name=$SIM" \
  -only-testing:InwardTests/ScreenshotTests \
  -resultBundlePath "$RESULT" >/dev/null

xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT" >/dev/null

python3 - "$EXPORT" docs/screenshots <<'PY'
import json, os, re, shutil, sys
base, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
manifest = json.load(open(os.path.join(base, "manifest.json")))
for entry in manifest:
    for att in entry.get("attachments", []):
        name = re.sub(r"_\d+_[0-9A-Fa-f-]+\.png$", ".png", att.get("suggestedHumanReadableName", ""))
        if not name.endswith(".png"):
            continue
        shutil.copyfile(os.path.join(base, att["exportedFileName"]), os.path.join(out, name))
        print("wrote docs/screenshots/" + name)
PY

echo "Done."
