# TOOLS.md — Command Surface & Dependencies

## Just Recipes

All workflows go through `just`. Recipes detect a non-bootstrapped repo and fail with guidance.

| Recipe | What it does | When to run |
|---|---|---|
| `just` | Lists all recipes | Orientation |
| `just bootstrap` | Runs `xcodegen generate` from `project.yml`, then resolves SPM dependencies | Once after cloning, and after editing `project.yml` or package manifests |
| `just build` | `swift build` of the core package, then `xcodebuild build` of the `Inward` scheme for iOS Simulator | Sanity check after structural changes |
| `just test` | `swift test` for the core SPM modules (runs on macOS, no simulator needed), then `xcodebuild test` on a simulator — prefers iPhone 16, falls back to the first available iPhone | After every change; TDD inner loop |
| `just lint` | `swiftlint` over the repo; skips with a notice when swiftlint is not installed (CI installs it) | Before committing; CI runs it |
| `just format` | `swiftformat .` | Before committing (hooks also format on edit) |
| `just ci` | `lint` + `build` + `test` — exactly what CI runs | Before pushing |

Prerequisites (macOS): Xcode 26+, `brew install just xcodegen swiftformat swiftlint`.
Note: simulator builds/tests use local ad-hoc signing — do not pass `CODE_SIGNING_ALLOWED=NO`; it strips the entitlements the keychain tests rely on.

## External Data Sources / APIs

By product invariant, Inward has **no external data APIs and no inference keys**. The dependency surface is OS frameworks and vendored libraries:

| Dependency | Kind | Auth | Cost/limits | Notes |
|---|---|---|---|---|
| SpeechAnalyzer / SpeechTranscriber | iOS framework (on-device ASR) | none | free; on-device | Primary ASR; requires iOS 26+ |
| FoundationModels (AFM 3 Core) | iOS framework (on-device LLM) | none | free; **8K context** — chunk + hierarchical summaries | `LanguageModelSession` + `@Generable`; feature-gate on availability |
| Core Spotlight + NLContextualEmbedding | iOS frameworks | none | free; on-device | Local index + embeddings for RAG |
| StoreKit 2 | iOS framework | App Store Connect config | Apple's 15/30% cut | **The only permitted network traffic in the app** |
| GRDB + SQLCipher | SPM packages | none | OSS | Encrypted local store |
| sqlite-vec | SPM/vendored | none | OSS | Vector search inside the same SQLite DB |
| whisper.cpp (small) | vendored | none | OSS; ~150MB model download decision pending | ASR fallback for pre-SpeechTranscriber devices |

If a change introduces any other network endpoint, stop and re-read AGENTS.md invariant #2.

## Environment Variables

The shipped app requires **zero** runtime env vars or secrets — this is a tested product invariant, not an omission.

| Variable | Scope | Purpose |
|---|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | CI only, M3+ | App Store Connect API for future release automation (fastlane/altool). Not needed for build/test. |

No values in the repo, ever; CI gets them as GitHub Actions secrets when release automation lands.

## Local Services

None. No Docker, no Postgres, no local model server. Everything runs inside the iOS Simulator / device. The on-device models are provided by the OS (FoundationModels) or bundled (whisper.cpp fallback).

## CI Overview (`.github/workflows/ci.yml`)

- Triggers: `push` and `pull_request`. Runner: `macos-26` (Xcode 26 / iOS 26 SDK — required by the app target and the SpeechTranscriber/FoundationModels availability guards).
- Steps: checkout → setup-just → `brew install swiftformat swiftlint` → **bootstrap guard** → (if bootstrapped) install xcodegen, `just bootstrap`, `just ci`.
- **Bootstrap guard:** if `project.yml` does not exist, CI emits a notice and skips build/test so a docs-only scaffold stays green. M0 landed `project.yml`, so the full `just ci` (lint + `swift test` + simulator build/test) runs on every push.

## AI Harness Notes

`.claude/settings.json` (copied verbatim from the iOS scaffold template):

- **Permissions:** allows `just`, `xcodebuild`, `xcrun`, `swift`, `swiftformat`, `swiftlint`, `xcodegen`, and read-only git.
- **PostToolUse hooks:** on every Write/Edit of a `*.swift` file — `swiftformat` runs (format-on-edit), then `swiftlint` reports the first 10 findings. Don't manually reformat; let the hook do it.

Most useful subagents for this repo:

- **tdd-guide** — start every new feature here; this repo is test-first by policy (no-egress, banned-terms, and safety-gate tests especially).
- **code-reviewer** — after any change; pay attention to Swift 6 concurrency and invariant adherence.
- **security-reviewer** — mandatory for anything touching `JournalStore`, `PrivacyKit`, `SafetyKit`, export, or keychain/biometrics: this is user mental-health data, the most sensitive class there is.
- **planner** — for milestone-sized work (M1 slice, M2 trust layer); break against DESIGN.md acceptance criteria.

Useful skills available in this environment: `swiftui-patterns`, `swift-concurrency-6-2`, `foundation-models-on-device`, `swift-actor-persistence`, `swift-protocol-di-testing`.
