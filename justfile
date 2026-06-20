# Inward — on-device voice journaling for iOS. Run `just` to list recipes; see TOOLS.md for details.

app := "Inward"
# Prefer the iPhone 16 (CI baseline); otherwise the first available iPhone simulator.
sim := `xcrun simctl list devices available 2>/dev/null | sed -nE 's/^[[:space:]]+(iPhone[^(]*)\(.*/\1/p' | sed -E 's/[[:space:]]+$//' | awk '$0=="iPhone 16"{print;found=1;exit}NR==1{first=$0}END{if(!found&&first!="")print first}'`

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
