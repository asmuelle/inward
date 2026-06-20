# App Store Connect setup

The source of truth for Inward's App Store listing, in-app purchases, and privacy
declaration. Listing text lives in `fastlane/metadata/` (uploadable with
`fastlane deliver`); this document covers what fastlane does not manage — the IAP
products and the App Privacy answers — plus the submission checklist.

> Compliance note: every public-facing string must avoid the regulated vocabulary
> (see `AGENTS.md` invariant #1). `ComplianceTests` scans both the in-app copy and
> `fastlane/metadata/**/*.txt` on every CI run, so the listing cannot regress.

## App record

| Field | Value |
|---|---|
| Bundle ID | `app.inward.Inward` |
| Name | Inward |
| Subtitle | Private voice journaling |
| Primary category | **Lifestyle** (recommended) |
| Secondary category | Productivity |
| Price | Free (with in-app purchases) |

Category rationale: Inward is positioned strictly as reflective journaling, not a
health or medical product. **Lifestyle** keeps it clear of medical-claim scrutiny;
avoid Health & Fitness, which invites review against medical guidelines and risks
the very framing invariant #1 forbids.

## In-app purchases

One subscription group plus one non-consumable. Product IDs must match
`Sources/PaywallKit/Products.swift` and `App/Tests/Inward.storekit` exactly.

### Subscription group: "Inward Membership"

| Reference name | Product ID | Type | Duration | Price (USD) | Intro offer |
|---|---|---|---|---|---|
| Inward Monthly | `app.inward.subscription.monthly` | Auto-Renewable | 1 month | 9.99 | 7-day free trial |
| Inward Yearly | `app.inward.subscription.annual` | Auto-Renewable | 1 year | 59.99 | 7-day free trial |

- Both subscriptions share the **same group** so a member can move between them and
  only ever holds one active entitlement.
- Intro offer: **Free, 1 week**, for new subscribers, on both products.
- Localized display names: "Monthly" and "Yearly".

### Non-consumable

| Reference name | Product ID | Type | Price (USD) |
|---|---|---|---|
| Inward Lifetime | `app.inward.lifetime` | Non-Consumable | 129.99 |

- Localized display name: "Lifetime".

### Per-product review notes (App Store Connect)

- Description (Monthly/Yearly): "Unlimited new writing and weekly reflections, all
  on device. 7-day free trial."
- Description (Lifetime): "Unlimited new writing and weekly reflections, all on
  device. Pay once."
- Screenshot: provide a screenshot of the in-app paywall (`PaywallView`).

> IAP products are not managed by `fastlane deliver`. Create them in App Store
> Connect, or script them with the App Store Connect API. They must be submitted
> **with the first app version** that contains them.

## App Privacy — "Data Not Collected"

Answer the privacy questionnaire as follows:

- **"Do you or your third-party partners collect data from this app?" → No.**

Justification (keep on file):

- No account, no login, no first-party server. The journaling path makes zero
  network requests — enforced by `PrivacyKit`'s no-egress test and verifiable by
  users via the iOS App Privacy Report.
- No analytics, attribution, crash-reporting, or advertising SDKs; no third-party
  SDK that phones home (invariant #6). App measurement, if any, is
  SKAdNetwork-aggregate only and is not "data collected by the developer."
- In-app purchases run through StoreKit. Apple processes the transaction under
  Apple's own privacy terms; the developer receives no personal data, so this does
  not constitute collection by Inward.
- The encrypted export is created on device and sealed with the user's passphrase;
  it is never transmitted to the developer.

A privacy policy URL is still required even when nothing is collected:

- Privacy policy: `https://asmuelle.github.io/inward/privacy.html`
  (published from `docs/privacy.html`; canonical copy in `PRIVACY.md`).

## Required Info.plist usage strings (already in `project.yml`)

- `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`,
  `NSFaceIDUsageDescription`.

## Submission checklist

- [ ] Create the three IAP products above (exact product IDs).
- [ ] Configure the 7-day free-trial intro offer on both subscriptions.
- [ ] Upload listing text: `fastlane deliver` (or paste from `fastlane/metadata/`).
- [ ] Set primary category **Lifestyle**, secondary Productivity.
- [ ] Set privacy policy URL; complete App Privacy as **Data Not Collected**.
- [ ] Replace the placeholder `support@inward.app` with a monitored address in
      `PRIVACY.md`, `docs/privacy.html`, and the ASC support URL/contact.
- [ ] Upload screenshots, including one of the paywall (required for IAP review).
- [ ] Add reviewer notes from `fastlane/metadata/review_information/notes.txt`
      (airplane-mode verification; no demo account needed).
- [ ] Confirm CI is green (`ComplianceTests` covers the metadata banned-terms lint).
