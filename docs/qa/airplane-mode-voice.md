# QA — Voice asset preflight & airplane-mode promise

On-device speech models ship separately from the app. On a fresh install the
language model for the user's locale may not be present, and the first recording
would otherwise need a one-time network download. Inward's promise — *"works in
airplane mode, nothing leaves this phone"* — must hold for voice **only after**
that model is installed, so the app surfaces an explicit, consented preflight and
never downloads mid-recording.

**This cannot be verified in the iOS Simulator** — audio capture and speech-model
installation are device-only. Run this checklist on a real iPhone/iPad (and a Mac
for the macOS target) before any TestFlight expansion.

## Preconditions
- A device with **no Inward speech model installed** for the test locale. To reset:
  Settings ▸ General ▸ Keyboard / Dictation languages, or use a language whose
  model you have not downloaded. A wiped/restored device is the cleanest state.
- A second device or known-good model-installed device for the offline-path test.

## A. First-run preflight (model absent)
1. Install the app, complete onboarding, tap record for the first time.
2. **Expect the preparation screen** ("Set voice up once"), *not* a silent spinner
   that reaches the network. Copy must state the one-time connection clearly.
3. With the device **online**, tap "Bring voice onto this phone". The model
   downloads, the screen returns to idle, and recording then begins.
4. Confirm "Write instead" on the preparation screen still saves a text entry.

## B. Offline promise holds (model present)
1. With the model installed (after A, or on a model-ready device), enable
   **airplane mode** (and confirm Wi-Fi/cellular are both off).
2. Record a voice entry end-to-end: live transcript appears, review, keep. It must
   succeed fully offline.
3. Type and save a written entry — must always work offline regardless of model.

## C. No silent egress during capture
1. Still in airplane mode, record several entries.
2. Disable airplane mode, then open **Settings ▸ Privacy & Security ▸ App Privacy
   Report**. Inward must show **no network activity** from the recording flow.
3. Re-confirm there is no "download" prompt or network reach when recording with the
   model already installed (the preflight should never re-trigger).

## D. Edge cases
- **Model absent + offline:** tapping "Bring voice onto this phone" should fail
  gracefully (voice unavailable / text still works), never hang.
- **Unsupported language:** a locale with no on-device model routes to
  "voice unavailable", not the preparation screen.
- **Interrupted download:** background/kill the app mid-download; on relaunch the
  preflight should reappear cleanly rather than leaving a half state.

## Automated coverage (what already guards this)
- `CaptureCoordinatorTests`: a *downloadable* model routes to preparation and the
  engine's `start()` is **never** called and **no** download is triggered; after
  `prepareVoice()` recording proceeds.
- `NoEgressTests`: the full mock journaling loop attempts **zero** network requests.
- The device tests above cover what the Simulator and unit tests cannot: the real
  `SpeechTranscriber`/`AssetInventory` install path and live audio.
