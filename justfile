# Inward — on-device voice journaling for iOS. Run `just` to list recipes; see TOOLS.md for details.

app := "Inward"
# Prefer the iPhone 16 (CI baseline); otherwise the first available iPhone simulator.
sim := `xcrun simctl list devices available 2>/dev/null | sed -nE 's/^[[:space:]]+(iPhone[^(]*)\(.*/\1/p' | sed -E 's/[[:space:]]+$//' | awk '$0=="iPhone 16"{print;found=1;exit}NR==1{first=$0}END{if(!found&&first!="")print first}'`

# Bundle id and dedicated derived-data paths for the install/launch recipes.
bundle    := "app.inward.Inward"
sim_dd    := "/private/tmp/inward-ios-sim-dd"
sim_app   := sim_dd + "/Build/Products/Debug-iphonesimulator/" + app + ".app"
device_dd := "/private/tmp/inward-ios-device-dd"
mac_dd    := "/private/tmp/inward-mac-dd"
mac_app   := mac_dd + "/Build/Products/Debug/" + app + ".app"

# List available recipes
default:
    @just --list --unsorted

# Generate the Xcode project via XcodeGen and resolve SPM dependencies
bootstrap:
    @if [ ! -f project.yml ]; then \
        echo "project.yml not found — this repo is still a docs-only scaffold."; \
        echo "Milestone M0 (DESIGN.md) adds project.yml + the SPM modules; create those first, then re-run 'just bootstrap'."; \
        exit 1; \
    fi
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project "{{app}}.xcodeproj" -scheme "{{app}}"

# Build: core SPM package for macOS, then the Inward scheme for the iOS Simulator.
# Simulator builds sign-to-run-locally; CODE_SIGNING_ALLOWED=NO would strip the
# entitlements the keychain tests depend on.
build: _require-project
    swift build
    xcodebuild build -project "{{app}}.xcodeproj" -scheme "{{app}}" \
        -destination "generic/platform=iOS Simulator"

# Run the test suites: core SPM tests on macOS, then app tests on the simulator (when one exists).
# StoreKit's SKTestSession does not load products on headless CI runners, so the
# StoreKitGatewayTests E2E suite is skipped on CI (GITHUB_ACTIONS) and runs locally only.
test:
    swift test --parallel
    @if [ -d "{{app}}.xcodeproj" ] && [ -n "{{sim}}" ]; then \
        skip=""; [ -n "${GITHUB_ACTIONS:-}" ] && skip="-skip-testing:InwardTests/StoreKitGatewayTests"; \
        xcodebuild test -project "{{app}}.xcodeproj" -scheme "{{app}}" \
            -destination "platform=iOS Simulator,name={{sim}}" $skip; \
    else \
        echo "Skipping simulator tests — {{app}}.xcodeproj missing (run 'just bootstrap') or no iPhone simulator available."; \
    fi

# Lint Swift sources with SwiftLint (skips gracefully when the tool is absent)
lint: _require-sources
    @if command -v swiftlint >/dev/null 2>&1; then \
        swiftlint; \
    else \
        echo "swiftlint not installed — skipping lint (CI installs it; locally: brew install swiftlint)."; \
    fi

# Format Swift sources with SwiftFormat
format: _require-sources
    swiftformat .

# Full gate: lint + build + test (exactly what CI runs)
ci: lint build test

# Render UI surfaces to docs/screenshots/ (uses the chosen simulator)
screenshots: _require-project
    ./scripts/screenshots.sh "{{sim}}"

_require-project:
    @if [ ! -d "{{app}}.xcodeproj" ]; then \
        echo "{{app}}.xcodeproj not found — run 'just bootstrap' first."; \
        echo "(If project.yml is missing too, the repo is a docs-only scaffold; see DESIGN.md M0.)"; \
        exit 1; \
    fi

_require-sources:
    @if [ ! -f project.yml ]; then \
        echo "No Swift project yet (project.yml missing) — nothing to lint or format."; \
        echo "Bootstrap per DESIGN.md M0 first."; \
        exit 1; \
    fi


# ─── native iOS build / run ─────────────────────────────────────────────
# Recipe shape adapted from ../agent-ssh. Inward is pure Swift (no Rust), so its
# uniffi/cargo, Sparkle, DMG and notarize recipes don't carry over — but the app
# is now a multiplatform iPhone/iPad/macOS target, so the mac-* recipes below do.

# Keychain and Face ID entitlements need the simulator signature Xcode emits,
# so this signs ad-hoc rather than passing CODE_SIGNING_ALLOWED=NO.
# Build the iOS Simulator app signed for local launch.
ios-sim-build: _require-project
    xcodebuild build -project "{{app}}.xcodeproj" -scheme "{{app}}" \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath {{sim_dd}} \
        ONLY_ACTIVE_ARCH=YES \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGN_IDENTITY="-"

# Pass a name fragment to target a specific device, e.g.
# `just run-on-sim "iPhone 16 Pro"`; defaults to a booted iPhone, then {{sim}}.
# Build, install, and launch on an iPhone simulator.
run-on-sim name="": ios-sim-build
    @app="{{sim_app}}"; \
    name="{{name}}"; \
    test -d "$app" || { echo "Simulator app not found: $app"; exit 1; }; \
    if [ -n "$name" ]; then \
        udid="$(xcrun simctl list devices available | grep 'iPhone' | grep -F "$name" | sed -nE 's/.*\(([0-9A-F-]{36})\).*/\1/p' | head -n1 || true)"; \
    else \
        udid="$(xcrun simctl list devices available | grep 'iPhone' | grep 'Booted' | sed -nE 's/.*\(([0-9A-F-]{36})\).*/\1/p' | head -n1 || true)"; \
        if [ -z "$udid" ]; then \
            udid="$(xcrun simctl list devices available | grep -F '{{sim}}' | sed -nE 's/.*\(([0-9A-F-]{36})\).*/\1/p' | head -n1 || true)"; \
        fi; \
    fi; \
    test -n "$udid" || { echo "No available iPhone simulator found"; xcrun simctl list devices available; exit 1; }; \
    if ! xcrun simctl list devices | grep "$udid" | grep -q 'Booted'; then \
        xcrun simctl boot "$udid" || true; \
        xcrun simctl bootstatus "$udid" -b; \
    fi; \
    open -a Simulator; \
    xcrun simctl install "$udid" "$app"; \
    xcrun simctl launch "$udid" "{{bundle}}"; \
    echo "Launched {{app}} on iPhone simulator $udid"

# arm64; pass a Team via xcodebuild env if you need a signed device build.
# Build the app for a connected device or archive workflow.
ios-build config="Debug": _require-project
    xcodebuild build -project "{{app}}.xcodeproj" -scheme "{{app}}" \
        -configuration {{config}} \
        -destination "generic/platform=iOS" \
        -derivedDataPath {{device_dd}} \
        ARCHS=arm64

# Open Inward.xcodeproj in Xcode.
ios-open: _require-project
    open "{{app}}.xcodeproj"

# Wipe iOS build outputs (simulator + device derived data).
ios-clean:
    rm -rf {{sim_dd}} {{device_dd}}
    @echo "✅ iOS build artifacts cleaned"


# ─── native macOS build / run ───────────────────────────────────────────
# Same multiplatform SwiftUI target as iOS. On macOS the journal is text-only
# (the SpeechTranscriber engine is iOS-only); the encrypted export/import that
# moves a journal between devices works on every platform.

# Compile-validate the macOS app without signing (mirrors the iOS CI build).
mac-build: _require-project
    xcodebuild build -project "{{app}}.xcodeproj" -scheme "{{app}}" \
        -destination "platform=macOS" \
        -derivedDataPath {{mac_dd}} \
        CODE_SIGNING_ALLOWED=NO

# Sandbox entitlements need automatic signing, so set your Apple Team ID once:
# `APPLE_DEVELOPMENT_TEAM=<id> just mac-run`.
# Build a signed macOS app and open it.
mac-run: _require-project
    @team="${DEVELOPMENT_TEAM:-${APPLE_DEVELOPMENT_TEAM:-}}"; \
      test -n "$team" || { echo "Set APPLE_DEVELOPMENT_TEAM=<Apple Team ID> to sign the sandboxed macOS app."; exit 1; }; \
      xcodebuild build -project "{{app}}.xcodeproj" -scheme "{{app}}" \
        -destination "platform=macOS" \
        -derivedDataPath {{mac_dd}} \
        -configuration Debug \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$team"
    open "{{mac_app}}"

# Run the app unit tests on macOS (core SPM tests already run under `just test`).
mac-test: _require-project
    xcodebuild test -project "{{app}}.xcodeproj" -scheme "{{app}}" \
        -destination "platform=macOS"

# Wipe macOS build outputs.
mac-clean:
    rm -rf {{mac_dd}}
    @echo "✅ macOS build artifacts cleaned"
