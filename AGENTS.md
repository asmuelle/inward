# AGENTS.md — Operating Manual for Inward

## Project Snapshot

Inward is a voice-first, verifiably airplane-mode-functional journaling app for iOS. Spoken thoughts are transcribed on-device (SpeechTranscriber), reflected on by an on-device model (FoundationModels AFM 3 Core), and stored only on the phone in a SQLCipher-encrypted database. Who pays: therapy-curious 25–45s currently paying Mindsera/Rosebud/Day One prices, via a hard paywall after a 7-day trial ($9.99/mo, $59.99/yr annual-first, $129.99 lifetime). Pipeline status: **recommended** (#2 of 9 finalists in the edge-AI run).

It is positioned strictly as **reflective journaling and pattern awareness**. It is not, and must never be described or built as, therapy or CBT. See Product Invariants below — they override everything else.

## Read First

1. `README.md` — research dossier: market evidence, adversarial review, recommended tech stack.
2. `DESIGN.md` — architecture, module map, data model, key flows, milestones (M0–M3), design direction.
3. `TOOLS.md` — every command, the (absence of) external APIs, CI behavior, harness notes.

## Commands

`just` is the single source of truth. Never invoke `xcodebuild`/`swiftlint`/`swiftformat` ad hoc when a recipe exists.

| Recipe | What it does |
|---|---|
| `just` | List recipes |
| `just bootstrap` | Generate `Inward.xcodeproj` via XcodeGen + resolve SPM dependencies |
| `just build` | Build the `Inward` scheme for iOS Simulator |
| `just test` | Run tests on the iPhone 16 simulator |
| `just lint` | SwiftLint over the repo |
| `just format` | SwiftFormat the repo |
| `just ci` | lint + build + test (what CI runs) |

Until M0 lands, the repo is docs-only; recipes fail with guidance instead of cryptic errors. That is expected.

## Architecture Summary

A thin SwiftUI app shell (XcodeGen `project.yml`) composes local SPM packages; data flows capture → on-device inference → encrypted store → surface, with a deterministic safety gate in front of every model call. All inference is on-device; the only permitted network traffic in the entire app is StoreKit.

| Package | Role |
|---|---|
| `CaptureKit` | Recording + SpeechTranscriber ASR + transcript editing |
| `JournalStore` | GRDB + SQLCipher store, NSFileProtectionComplete, migrations |
| `RecallKit` | Local RAG: embeddings + sqlite-vec + Core Spotlight |
| `ReflectKit` | FoundationModels sessions, @Generable outputs, 8K-window chunking |
| `SafetyKit` | Deterministic crisis keyword gate + static resources |
| `PrivacyKit` | No-egress harness, encrypted export, biometric lock |
| `PaywallKit` | StoreKit 2 trial/paywall/entitlements |
| `DesignSystem` | Lamplight-paper tokens, typography, components |

## Current State & First Tasks

- The repo is a docs-only scaffold: no `project.yml`, no Swift sources yet. `just` recipes fail with guidance and CI's bootstrap guard keeps the pipeline green — both intentional.
- The next unit of work is **M0** (DESIGN.md): `project.yml` + the eight SPM package stubs, each with one passing test, until `just bootstrap && just ci` is green locally and in Actions.
- Do not modify `README.md` — it is the frozen research dossier this scaffold was derived from.
- Do not add dependencies that open network paths (analytics, crash reporters, remote config). If a library wants the network, it does not belong here.
- When in doubt about scope or wording, the legal framing in DESIGN.md ("Hard Constraint") and the invariants below decide.

## Coding Standards

- Swift 6, strict concurrency enabled; prefer value types and `Sendable`; actors for shared mutable state (the store, the model session).
- Files < 800 lines, functions < 50 lines; split before you exceed.
- Immutability by default — return new values, don't mutate inputs.
- Explicit error handling at every boundary: typed throws or `Result`; no `try!`/`try?` swallowing in production paths; degrade gracefully (journaling must work when the model doesn't).
- No hardcoded secrets — and this app should have none at all: any new API key is a design smell (see invariants).
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- `swiftformat` + `swiftlint` are enforced via hooks and CI; don't fight them.

## Testing Policy

- TDD: write the failing test first (Swift Testing preferred; XCTest where UI/StoreKitTest requires it). 80%+ coverage target. AAA structure, behavior-describing names.
- Tests that matter most for THIS product, in order:
  1. **No-egress tests** — URLProtocol interceptor fails any test that triggers a network request from the journaling path.
  2. **Banned-terms tests** — scan all user-facing strings (and store-metadata fixtures) for the therapy/CBT lexicon.
  3. **SafetyKit gate tests** — seeded crisis fixtures must suppress model invocation and surface static resources.
  4. **Encryption tests** — DB file unreadable without key; export artifacts encrypted.
  5. **Citation validity** — every weekly-review observation cites entry IDs that exist.
  6. **Token-budget tests** — chunking/summary logic stays under the 8K context window on long fixtures.
  7. StoreKitTest flows (M3): trial expiry, purchase, restore, lifetime.
- Snapshot tests for key Lamplight-paper surfaces (home, entry, weekly review) in light + dark.

## PRODUCT INVARIANTS (non-negotiable)

Violating any of these is a release blocker, regardless of who asked for the change.

1. **No therapy language, anywhere.** User-facing strings, App Store metadata, paywall copy, notifications, and marketing must never contain: therapy, therapist, CBT, cognitive behavioral, cognitive distortion, diagnose/diagnosis, treatment, counseling, mental health treatment, or clinical claims. Enforced by a CI banned-terms test. The Illinois WOPR Act regulates the service, not the server — on-device computation is not a legal shield.
2. **Zero network in the journaling path.** Capture, transcription, reflection, retrieval, storage, and export must produce zero network requests. Only StoreKit may touch the network. Enforced by the PrivacyKit no-egress test harness; verifiable by users via iOS App Privacy Report.
3. **All inference on-device.** SpeechTranscriber (whisper.cpp fallback) for ASR; FoundationModels for generation. No cloud LLM APIs, no inference API keys in the app — ever. Frontier models are permitted only in dev-time eval tooling, never in shipped code.
4. **Encryption at rest.** Single SQLCipher database + `NSFileProtectionComplete` for all entry content and audio. A test must prove the DB file is unreadable without the key.
5. **Crisis handling is deterministic.** SafetyKit's keyword gate runs before every model call; on match, the model is suppressed and static, localized resources are shown. An AI-generated response (or a model refusal) must never be what a user in crisis sees.
6. **No analytics or tracking SDKs.** No third-party SDK that phones home. Measurement is SKAdNetwork-aggregate only. App Privacy label stays "Data Not Collected."
7. **Reflections are grounded.** Weekly reviews must cite real entry IDs; invalid citations cause regeneration or deterministic fallback — never fabricated synthesis.
8. **Users always own their data.** Reading existing entries and encrypted export are never paywalled, never gated, never degraded.
9. **Model-optional journaling.** Every capture/store/read flow must fully work when Apple Intelligence is unavailable.

## Definition of Done

- [ ] Failing test written first; now green; coverage ≥ 80% on touched code
- [ ] `just ci` passes locally (lint + build + test)
- [ ] No invariant violated (run the no-egress + banned-terms suites if you touched strings, networking, or model code)
- [ ] Errors handled explicitly at every new boundary; graceful degradation when model/ASR unavailable
- [ ] Files < 800 lines, functions < 50; Swift 6 concurrency clean (no warnings suppressed)
- [ ] User-facing copy matches the Lamplight-paper tone (quiet, non-clinical) and the legal framing
- [ ] Conventional commit message; docs (DESIGN.md/TOOLS.md) updated if behavior or commands changed
