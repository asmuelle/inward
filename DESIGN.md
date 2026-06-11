# Inward — Design Document

## Thesis

Cloud journaling incumbents (Mindsera, Rosebud, Reflection) sell privacy claims they cannot prove, while regulators (Illinois WOPR, FTC 6(b), NY disclosure rules) squeeze anything that smells like AI therapy. Inward wins by making the privacy claim *verifiable* — voice in, reflection out, with provably zero network traffic in the journaling path — and by staying legally untouchable as a reflective journaling and pattern-awareness tool, never a therapy product. On-device inference means ~$0 marginal cost per user, which unlocks a lifetime tier no cloud competitor can match.

## Hard Constraint (binding, from legal review)

The Illinois WOPR Act regulates the *service*, not the server location. Running models on-device does NOT exempt therapy claims. Therefore:

- Never market, describe, or implement Inward as therapy, CBT, counseling, diagnosis, or treatment.
- No "cognitive distortion" detection or labeling anywhere — UI, code identifiers in user-facing contexts, App Store copy, marketing.
- Allowed framing: reflective journaling, voice journaling, pattern awareness, themes, recurring topics, self-reflection prompts.
- Crisis-adjacent content is handled by deterministic keyword matching that surfaces static resources — never AI-generated advice.

Every other decision in this document is downstream of this constraint.

## Architecture

iOS-first (iOS 26+), Swift 6 strict concurrency, SwiftUI, modular SPM targets composed by a thin app shell generated via XcodeGen (`project.yml`). Everything runs on-device.

> **Implementation note (M0/M1):** the modules live as targets of a single root `Package.swift` (`Sources/<Module>`, `Tests/<Module>Tests`) rather than separate packages under `Packages/` — same module map, one manifest, and the whole core builds and tests on macOS via `swift test` with no simulator required. Platform AI (SpeechTranscriber, FoundationModels) sits behind protocols with deterministic mocks; real implementations are `#if canImport` + `@available`-guarded.

**Data flow:** capture → on-device inference → encrypted store → surface.

```
Mic / keyboard
   │
   ▼
CaptureKit ── SpeechTranscriber (on-device ASR) ──► transcript
   │                                                   │
   ▼                                                   ▼
SafetyKit (deterministic keyword gate) ──► JournalStore (GRDB + SQLCipher)
   │ (on match: static resources,                      │
   │  suppress model output)                           ├──► RecallKit (embeddings + sqlite-vec,
   ▼                                                   │     Core Spotlight local index)
ReflectKit (FoundationModels AFM 3 Core,               │
   @Generable structured output) ◄── retrieved context ┘
   │
   ▼
SwiftUI surfaces (timeline, entry, weekly review, paywall)
```

### Module map (SPM packages under `Packages/`)

| Package | Responsibility |
|---|---|
| `CaptureKit` | Audio recording, SpeechTranscriber on-device ASR, live transcript editing UI |
| `JournalStore` | GRDB + SQLCipher encrypted store, `NSFileProtectionComplete`, migrations, entity types |
| `RecallKit` | Local RAG: NLContextualEmbedding (or small Core ML embedder) + sqlite-vec, Core Spotlight indexing, retrieval for reviews |
| `ReflectKit` | FoundationModels `LanguageModelSession`, @Generable reflection/theme/review types, prompt persona with few-shot exemplars, 8K-window chunking via token-count APIs, hierarchical entry summaries |
| `SafetyKit` | Deterministic crisis keyword matcher, static resource directory (bundled, localized), model-output suppression gate |
| `PrivacyKit` | No-egress assertion harness (debug URLProtocol interceptor), client-side-encrypted export to Files/iCloud Drive, biometric lock |
| `PaywallKit` | StoreKit 2, 7-day trial, hard paywall, entitlement cache |
| `DesignSystem` | Tokens, typography, components, motion |
| `Inward` (app shell) | Composition root, navigation, onboarding; no business logic |

### Compute placement (cost discipline)

| Tier | Used for | Notes |
|---|---|---|
| Deterministic code | Capture, storage, search, streaks/stats, crisis keyword gate, export, paywall logic | Always first choice; safety gate is *never* a model |
| On-device model (AFM 3 Core, ~$0/query) | Reflection prompts, theme tagging, entry summaries, weekly review synthesis | @Generable structured output only; chunk under 8K context with hierarchical summaries |
| Frontier model (cloud) | **Never at runtime.** Development-time only: prompt eval harnesses, test fixture generation | A cloud call in the shipped journaling path is a release blocker |

Whisper.cpp (small) is the ASR fallback for devices without SpeechTranscriber. If Apple Intelligence is unavailable, journaling fully works; reflection surfaces show a graceful "reflections unavailable on this device" state.

## Data Model Sketch

All tables live in the single SQLCipher database. No row ever leaves the device except via user-initiated encrypted export.

- **Entry** — `id`, `createdAt`, `source` (voice/text), `audioFileRef?`, `transcriptRaw`, `textEdited`, `durationSec?`, `mood?` (user-set, optional), `locale`
- **Transcription** — `entryId`, `engine` (speechTranscriber/whisper), `confidence`, `completedAt` (provenance for ASR quality debugging)
- **Reflection** — `id`, `entryId?`, `kind` (prompt/themes/entrySummary/weeklyReview), `payload` (structured, from @Generable), `modelVersion`, `generatedAt`
- **WeeklyReview** — `id`, `weekStart`, `summaryPayload`, `citedEntryIds` (must reference real entries), `generatedAt`
- **ThemeTag** — `id`, `name`, `firstSeenAt`; join table `EntryTheme` (`entryId`, `themeId`, `derivedBy` model/user)
- **EmbeddingChunk** — `entryId`, `chunkIndex`, `textRange`, `vector` (sqlite-vec virtual table)
- **SafetyEvent** — `id`, `entryId`, `categoryMatched`, `resourceShownId`, `at` (local only, never exported by default, lets us test the gate)
- **Entitlement** — `productId`, `state` (trial/active/expired/lifetime), `expiresAt?`, `lastVerifiedAt` (StoreKit 2 cache)
- **Settings** — biometric lock flag, reminder schedule, ASR locale, export preferences

## Key Flows

### 1. Voice capture (the core loop — must work in airplane mode)
1. User taps record on the home surface; mic permission already granted in onboarding.
2. `CaptureKit` streams audio to SpeechTranscriber; live transcript renders as the user speaks.
3. On stop, user can edit the transcript inline (serif entry typography, calm surface).
4. Save: `JournalStore` writes Entry + Transcription inside one transaction to the SQLCipher DB; audio file stored with `NSFileProtectionComplete` (or discarded if the user disables audio retention).
5. `RecallKit` embeds the entry into sqlite-vec and indexes it in Core Spotlight — all local, off the main actor.
6. Zero network requests occurred. The debug no-egress harness asserts this in tests.

### 2. Reflection after an entry
1. On save, `SafetyKit` runs the deterministic keyword gate over the final text.
2. **If matched:** static, localized crisis resources are surfaced; ReflectKit is *not invoked* for this entry; a SafetyEvent is recorded. The model never speaks at the darkest moments — by design, since AFM guardrails refuse exactly there.
3. If clear: `ReflectKit` opens a `LanguageModelSession` with the persona prompt + few-shot exemplars, passes the entry (token-counted, chunked if needed), and requests a @Generable `ReflectionPrompt` (1–2 open questions + up to 3 theme tags).
4. Output is validated (schema, banned-terms scan) before display; failures degrade to "no reflection" — never raw model text.
5. Reflection + ThemeTags persist to the store.

### 3. Weekly review with citations
1. Sunday evening (local notification, user-scheduled), the app assembles the week: per-entry summaries (precomputed at save time to stay under the 8K window) + RecallKit retrieval of related older entries by theme.
2. `ReflectKit` synthesizes a @Generable `WeeklyReview`: recurring themes, one gentle observation per theme, each citing ≥1 `entryId` that exists in the store.
3. UI renders each observation with tappable citations that open the original entries — the trust artifact.
4. Reviews with invalid citations are rejected and regenerated once; second failure shows themes-only (deterministic counts) without synthesis.

### 4. Airplane-mode proof (onboarding + marketing surface)
1. Onboarding invites the user to enable airplane mode and record their first entry.
2. The proof screen shows: airplane-mode state, entry saved, transcript produced, and points to iOS App Privacy Report ("check it — no network activity").
3. This flow doubles as the demo for App Store screenshots and launch content.

### 5. Trial → hard paywall
1. Days 1–7: full functionality, trial state from StoreKit 2.
2. Day 8: hard paywall — new capture and reflections lock; reading existing entries and export always remain free (users own their words; export is never paywalled).
3. Annual-first paywall: $59.99/yr highlighted, $9.99/mo, $129.99 lifetime ("no servers, no subscription required to keep your words yours").
4. Purchase/restore via StoreKit 2; entitlement cached locally; no receipts sent to any first-party server (there is none).

## Product & Visual Design Direction

**Lamplight paper** — a warm, analog stationery feel: a fine notebook by lamplight, not a clinical health dashboard and not a techy dark-mode chat app.

- **Palette:** unbleached-paper warm white `#F7F2E9` surfaces; ink charcoal `#2B2620` text; muted clay accent `#B5654A` for record/CTA; dried-sage `#7C8471` for themes/metadata. Dark theme is "lamplight," a warm brown-charcoal `#211D18` with amber-shifted text — never pure black.
- **Typography:** New York (Apple serif) for entry text, reflections, and review prose at generous sizes and 1.5+ line height; SF Pro for chrome, labels, and the paywall. Two families, no more.
- **Texture & depth:** subtle paper grain on entry surfaces; layered cards with soft warm shadows; the record button is the single strongest visual element on the home screen.
- **Motion:** breathing-pace transitions (300–450ms, ease-out), waveform pulse while recording; everything respects Reduce Motion.
- **Tone of copy:** quiet, second-person, never instructive or clinical ("What kept coming back this week" — not "Your cognitive patterns").

## Milestones

### M0 — Bootstrap (make `just ci` green)
- `project.yml` (XcodeGen) defining the `Inward` app target + scheme, wiring local SPM packages.
- All packages from the module map exist with compiling stubs and one passing Swift Testing test each.
- `.swiftlint.yml` + `.swiftformat` configured; `just bootstrap && just ci` passes locally and in GitHub Actions on macos-15.
- **Accept:** CI green with lint + build + test on iPhone 16 simulator.

### M1 — Thin vertical slice: voice in, encrypted entry out
- Record → live SpeechTranscriber transcript → edit → save to SQLCipher store → entry appears in timeline → reopen and read. Text-entry fallback included.
- Works with networking fully disabled (simulator network conditioner / airplane mode on device).
- **Accept:** E2E UI test of the loop; test proving the DB file is unreadable without the key; no-egress test asserting zero network requests during the loop; DesignSystem tokens applied (this slice already looks like Lamplight paper).
- *Status note:* M1 ships with `EncryptedFileJournalStore` (single AES-GCM-sealed file via CryptoKit, key in the device keychain, `NSFileProtectionComplete` on iOS) behind the `JournalStoring` protocol; the GRDB+SQLCipher store swaps in behind the same protocol in M2 without touching callers. The unreadable-without-key, wrong-key-fails-closed, and no-egress tests are in place and green.

### M2 — Trust layer
- ReflectKit reflections + weekly review with verified entry citations; SafetyKit gate live and tested ahead of every model call.
- PrivacyKit: debug no-egress harness wired into `just test`; biometric lock; client-side-encrypted export; airplane-mode proof screen in onboarding.
- Banned-terms test (therapy/CBT/diagnosis lexicon) running over all user-facing strings in CI.
- **Accept:** every weekly-review observation cites ≥1 real entry (tested); safety gate suppresses model output on seeded crisis fixtures (tested); App Privacy Report shows no journaling-path network activity in a manual device pass.

### M3 — Monetization wiring
- StoreKit 2 products: $9.99/mo, $59.99/yr (annual-first), $129.99 lifetime; 7-day trial; hard paywall honoring "reading + export never paywalled."
- StoreKitTest coverage for trial expiry, purchase, restore, lifetime.
- Paywall + App Store metadata pass the banned-terms lint; App Privacy "Data Not Collected" label justified and accurate.
- **Accept:** full trial→paywall→purchase→restore loop green under StoreKitTest; metadata reviewed against the legal constraint.

## Risks & Mitigations (from the adversarial review)

| # | Risk | Mitigation |
|---|---|---|
| 1 | **Regulatory:** CBT/therapy framing is the regulated *service*; on-device exempts nothing (Woebot exposure, locally computed) | Hard product invariant: zero therapy/CBT/distortion language anywhere; CI banned-terms test over all user-facing strings and store metadata; position is journaling + pattern awareness, which is the WOPR-exempt category |
| 2 | **Model quality ceiling:** AFM 3 Core (~3B active, 8K ctx) yields repetitive reflections vs frontier-calibrated users | Reflection is the garnish, not the meal: capture speed + longitudinal recall are the core value; hierarchical summaries to stretch the window; persona + few-shot exemplars + anti-repetition checks against recent reflections; ship variety evals |
| 3 | **Guardrail refusals on the darkest entries** — product fails at the defining moment, with liability | SafetyKit deterministic gate runs *before* any model call; on match the model is suppressed and static localized crisis resources surface; a refusal can never be the user-facing response (tested with seeded fixtures) |
| 4 | **Platform absorption:** Day One or Apple Journal flips on on-device reflections via the WWDC26 abstraction layer | Moat is the integrated loop incumbents won't ship quickly: voice-first capture + encrypted store + cited longitudinal reviews + lifetime pricing (cloud rivals can't match $0 marginal cost); ship M1–M2 fast and own the "verifiable" positioning before it commoditizes |
| 5 | **Distribution without analytics or viral loops** (hard paywall, zero data collection, $30–80 CPIs) | Airplane-mode proof as launch content (HN/press/creator demos); ASO on voice-journaling + privacy keywords; SKAdNetwork-only aggregate measurement; lifetime tier as a press hook; treat Android as later land-grab, not launch scope |

Secondary watch items: 8K context limits longitudinal claims (mitigated by summary-of-summaries; never promise "remembers everything"); Android NPU/API fragmentation (out of scope until iOS proves retention).
