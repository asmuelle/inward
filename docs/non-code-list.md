# Non-Code Launch Plan

Everything left between "the code is ready" (true as of `dca2fb0`, CI green) and
"Inward is live on the App Store." No item below requires writing app code;
two items need trivial config edits and are marked as such.

Companion reference: [app-store-connect.md](app-store-connect.md) holds the ASC
field values (IAP IDs, categories, privacy answers). This file is the ordered
execution plan.

---

## Phase 0 — Accounts & agreements (do first; longest external lead times)

Everything else can stall on these, and none of it is under our control.

- [ ] **Apple Developer Program** membership active; note the Team ID
      (builds sign with `APPLE_DEVELOPMENT_TEAM` env — nothing is committed).
- [ ] **Paid Applications agreement** signed in ASC (Business → Agreements).
      Subscriptions cannot even be created without it. Banking and tax forms
      complete and in "Active" state — approval can take days.
- [ ] **Sandbox test account** created (Users & Access → Sandbox) for device
      IAP testing in Phase 2.
- [x] Hosted privacy policy live — verified 200 at
      `https://asmuelle.github.io/inward/privacy.html` with monitored contact.

**Exit criteria:** ASC shows Paid Apps agreement "Active"; Team ID known.

---

## Phase 1 — Decisions (30 minutes, blocks later phases)

Decide once, in writing, so nothing downstream churns:

1. **Version string.** `MARKETING_VERSION` is `0.1.0`; ship `1.0.0` instead
   (user-visible on the product page). *Trivial `project.yml` edit.*
2. **Pricing.** Products are coded for $9.99/mo, $59.99/yr, $129.99 lifetime.
   The 2026-07 roadmap review suggested ~$39.99/yr. Decide **before** creating
   the IAPs — subscription price changes after launch trigger user-facing
   consent flows; getting it right now is much cheaper.
3. **iPad: keep or cut for v1.** `TARGETED_DEVICE_FAMILY` is `1,2`, so ASC
   will demand 13" iPad screenshots and reviewers will run it on iPad. If the
   iPad layout hasn't been QA'd, shipping iPhone-only (`TARGETED_DEVICE_FAMILY
   = 1`, *trivial `project.yml` edit*) is the lower-risk launch; add iPad in
   1.1. If keeping iPad: add an iPad pass to Phase 2 QA and iPad shots to
   Phase 4.
4. **Metadata locales.** App UI ships in 10 languages; listing text exists in
   `en-US` only. Recommended: launch en-US-only, add locales post-launch.
   (If localizing now, add ~1 day to Phase 4 and native review to Phase 3.)

**Exit criteria:** four decisions recorded (edit them into this file).

---

## Phase 2 — On-device QA (0.5–1 day; needs a physical iPhone on iOS 26)

None of this is Simulator-testable (audio is device-only). Work through
`docs/qa/airplane-mode-voice.md` first, then the launch-specific list:

**Voice pipeline (core promise):**
- [ ] Full capture → transcription in airplane mode (speech model must already
      be downloaded; also test the *download consent* path on first run).
- [ ] Spoken-summary confirm loop (Settings toggle ON): record → summary is
      spoken → Keep / Add more both behave; "Add more" appends across rounds
      (cap 2).
- [ ] **Known seam:** the `.record` → `.playback` audio-session handoff in
      `AVSpeechSynthesisEngine` — listen for clicks, dropped audio, or a dead
      mic on re-record.
- [ ] **Known gap:** dismissing capture mid-speech lets the current utterance
      finish (sync `reset()` can't await `stop()`). Judge on device whether
      it's acceptable for v1 or needs the async cancel path (code follow-up).
- [ ] FoundationModels recap quality on an Apple-Intelligence-enabled device;
      confirm the Deterministic fallback reads sensibly on a non-AI device.
- [ ] Personal-lexicon biasing: save entries with unusual names, confirm
      recognition improves on later recordings.

**Guideline-sensitive surfaces (what a reviewer will poke):**
- [ ] Paywall with the **sandbox account**: products load (they'll 404 until
      Phase 3 IAPs exist — retest after), 7-day trial shown, purchase, restore
      on a second install, lifetime purchase path.
- [ ] Crisis gate: a test phrase triggers quiet save + resources in weekly
      review; spoken summary is suppressed (`.suppressed`), never a breezy
      recap.
- [ ] Face ID lock on/off; lock respected by weekly-reminder deep link and
      widget/Control Center quick capture.
- [ ] Weekly reminder fires at the configured day/time; notification opens the
      review; denial path falls back cleanly.
- [ ] Export → wipe (delete app) → reinstall → import round-trip with a
      passphrase.
- [ ] Widget + Control Center in all 9 languages spot-check (2–3 languages);
      App Shortcuts/Siri phrases: verify what `--no-app-shortcuts-localization`
      actually ships and note the gap as a known 1.1 item.
- [ ] App Privacy Report (Settings → Privacy) after a day of use: journaling
      path shows **no network activity** — this is the marketing claim.

**Exit criteria:** checklist green, or every red item explicitly accepted /
turned into a code ticket.

---

## Phase 3 — Content & translation review (parallel with Phase 2; needs humans)

- [ ] **Crisis copy professional review.** The localized crisis lexicons and
      support-resource copy are machine-drafted and flagged for **native +
      professional review** — this is a launch gate, not polish. Scope: the
      `CrisisLexicon`/`SupportResource` localizations, 9 languages.
      (Reminder: the absence of per-country hotline numbers is a *deliberate
      decision* — findahelpline.com/IASP/112-only. Do not "fix" it; a
      verified-numbers sourcing pass is a sanctioned future task.)
- [ ] Native spot-check of the AI-drafted UI translations, priority order:
      paywall strings (money), onboarding, spoken-summary confirm loop, the
      new legal-link labels.
- [ ] Proofread `fastlane/metadata/en-US/*` one final time; confirm the
      description matches the *shipped* paywall model (capture free, insights
      gated) — it was written before the inversion.

**Exit criteria:** a named human has signed off on crisis copy per language
(or the language ships English-fallback for crisis surfaces — decide).

---

## Phase 4 — App Store Connect configuration (0.5 day once Phase 0–1 done)

Work top-to-bottom in ASC; values live in `app-store-connect.md`:

1. **App record:** bundle `app.inward.Inward`, name "Inward", subtitle
   "Private voice journaling", primary locale en-US, SKU (e.g. `inward-001`).
2. **Categories:** Lifestyle (primary), Productivity (secondary).
3. **IAPs** (exact IDs — code loads these strings):
   - Subscription group "Inward Membership":
     `app.inward.subscription.monthly`, `app.inward.subscription.annual`,
     both with the 7-day free intro offer, prices per Phase 1 decision.
   - Non-consumable `app.inward.lifetime`.
   - Localized display names/descriptions (en-US minimum); **review
     screenshot** attached to each IAP (the paywall shot from Phase 5).
4. **App Privacy:** "Data Not Collected" (justification is on file — the
   privacy manifest in the binary asserts the same).
5. **Age rating questionnaire:** answer honestly re: self-harm-adjacent
   crisis content (the app *responds* to it, doesn't depict it). Expect
   **12+**; record the actual answers in `app-store-connect.md` for
   repeatability. Do not engineer for 4+ — it would contradict the crisis
   features.
6. **Export compliance:** binary declares `ITSAppUsesNonExemptEncryption=YES`.
   Answer ASC's questions as non-exempt (SQLCipher, mass-market 5D992.c);
   **calendar a recurring January reminder for the annual US BIS
   self-classification report**; keep the French declaration handy if
   distributing in France.
7. **URLs:** support + marketing `https://asmuelle.github.io/inward/`,
   privacy `…/privacy.html`.
8. **Review notes:** paste `fastlane/metadata/review_information/notes.txt`
   (airplane-mode steps; no account → no demo credentials). Add one line
   pointing the reviewer at the free trial so the "expired = read-only"
   state never confuses them.
9. **Pricing & availability:** territories (default: all), price per Phase 1.

**Exit criteria:** app record shows "Prepare for Submission" with no missing
metadata warnings; all three IAPs in "Ready to Submit".

---

## Phase 5 — Screenshots & assets (0.5 day; after Phase 2 so screens are final)

The 9 drafts in `docs/screenshots/` are window-hosted renders (no status bar)
at 6.1" — **not submission-grade**.

- [ ] Confirm ASC's current required sizes when uploading; expect **6.9"
      iPhone** (1320×2868) as the primary set, plus **13" iPad** (2064×2752)
      if iPad survived Phase 1.
- [ ] Capture on Simulator (`Cmd+S` gives clean status bars) or device, in
      order: 1 timeline, 2 capture, 3 weekly review, 4 mind map, 5 proof/
      airplane mode, 6 entry detail, 7 settings/lock, 8 **paywall** (also
      attached to each IAP), 9 export. First 3 are what 90% of visitors see.
- [ ] Keep the offline/private framing consistent with the listing copy;
      no regulated mental-health vocabulary in any caption overlay
      (`ComplianceTests` doesn't scan images — self-police).
- [ ] Skip app-preview videos for v1.

**Exit criteria:** full screenshot set uploaded in ASC; paywall shot attached
to all three IAPs.

---

## Phase 6 — Build, TestFlight, submit (0.5 day)

- [ ] Bump `MARKETING_VERSION` to the Phase 1 choice (*trivial edit*),
      `xcodegen generate`, commit via PR.
- [ ] **Manual Xcode archive** (Product → Archive, iOS, Team ID selected;
      automatic signing). There is deliberately no fastlane/CI upload lane for
      v1 — building one is a post-launch nicety.
- [ ] Validate the archive in Organizer before upload (catches missing
      manifests/entitlements) → Distribute → App Store Connect.
- [ ] Upload should **not** prompt for export compliance (the plist key
      answers it) — if it does, something regressed.
- [ ] TestFlight internal testing: install on the QA device, one smoke pass
      of the Phase 2 guideline-sensitive list against the *distributed* build
      (sandbox IAPs now real).
- [ ] Attach the build to the version in ASC; **select all three IAPs to be
      submitted with the app** (first-time IAPs must ride along).
- [ ] Choose **phased release** (recommended) and submit for review.

**Exit criteria:** status "Waiting for Review".

---

## Phase 7 — Review window & launch day

- [ ] Monitor Resolution Center; typical review 24–48h. Likely rejection
      vectors, pre-answered: subscription terms visibility (3.1.2 links now on
      the paywall), crisis handling (deterministic gate + resources), offline
      claim (reviewer can verify in airplane mode per the notes).
- [ ] If rejected: respond in Resolution Center first — most 3.x issues
      resolve with a reply or metadata tweak, not a new binary.
- [ ] On approval (before phased release completes):
  - [ ] Swap the two "Coming soon" badges on `docs/index.html` for the real
        App Store link (*trivial edit, PR*).
  - [ ] Add the App Store link to `README.md`.
  - [ ] Verify the live product page: screenshots, price, privacy label.
  - [ ] Buy the cheapest product with a real account — confirm the money path.
- [ ] Watch the support inbox (`herban.mueller@gmail.com`) daily for the
      first two weeks; App Review sometimes writes there too.

---

## Post-launch backlog (not launch-gated, don't let it creep in)

| Item | Why it waits |
|---|---|
| fastlane `deliver`/`pilot` lanes + CI archive | manual flow suffices for v1 |
| Localized listing metadata (9 locales) | en-US decision in Phase 1 |
| App Shortcuts / Siri phrase localization | needs on-device verification, known gap |
| Verified per-country crisis hotline sourcing pass | sanctioned follow-up, safety-critical, unhurried |
| Async cancel path for mid-speech dismiss | pending Phase 2 verdict |
| `Package.swift` platform floor vs app target (iOS 17 vs 26) reconciliation | cosmetic consistency |
| Apple journal-suggestions entitlement application (Moment Seeds) | 1.1 feature |
| Annual BIS self-classification report | due each January |

---

## Critical path

```
Phase 0 (agreements) ──┬─► Phase 4 (ASC config) ─► Phase 5 (screenshots*) ─► Phase 6 (build+submit) ─► Phase 7
Phase 1 (decisions) ───┘            ▲
Phase 2 (device QA) ────────────────┘  (paywall retest once IAPs exist)
Phase 3 (translation review) ───────┘  (crisis-copy sign-off gates submission)
```

\*Phase 5 depends on Phase 2 only insofar as screens must be final.

**Realistic total: 2–3 focused days** of your time once the Paid Apps
agreement is active — the calendar time is dominated by Phase 0 processing
and the 24–48h review window.
