# Screenshots

Rendered from the real production SwiftUI surfaces by `ScreenshotTests`
(`App/Tests/ScreenshotTests.swift`) with seeded sample data, then extracted from
the test result bundle.

Regenerate with:

```bash
just bootstrap   # once
just screenshots # or: scripts/screenshots.sh "iPhone 17 Pro"
```

| File | Surface |
|---|---|
| `01-onboarding.png` | First-run airplane-mode proof |
| `02-timeline.png` | Home timeline |
| `03-entry-detail.png` | A kept entry |
| `04-capture.png` | Voice capture (idle) |
| `05-weekly-review.png` | Weekly review with cited entries |
| `06-settings.png` | Settings (lock + export) |
| `07-export.png` | Encrypted export |
| `08-paywall.png` | Membership paywall |
| `09-lock.png` | Biometric lock screen |
| `10-share-proof.png` | Share card — the offline proof |
| `11-share-themes.png` | Share card — the week in words |
| `12-share-mindmap.png` | Share card — the constellation |
| `13-threads-map.png` | Mind map — the Threads source, a month drawn as one cited tree |

## App Store screenshot order (not the same as this file order)

The first two frames decide the download; almost nobody swipes past three. Lead
with the claim nobody else can make, not with onboarding chrome:

| Slot | Source | Caption |
|---|---|---|
| 1 | `01-onboarding.png` (airplane-mode proof) | Turn on airplane mode. Use the whole app. |
| 2 | `04-capture.png` | Speak. It's written down, on this phone only. |
| 3 | `05-weekly-review.png` | What kept coming back — linked to your own words. |
| 4 | `07-export.png` | Your journal, encrypted, yours to take. |
| 5 | `02-timeline.png` | Everything you've said, searchable, offline. |
| 6 | `08-paywall.png` | *(required by App Review for the IAP)* |

Slots 1–3 carry the whole pitch; 4–6 are for people already scrolling. The share
cards (`10`–`12`) are launch-content assets, not product-page screenshots.

## Notes

- These are window-hosted snapshots (`UIHostingController` + `drawHierarchy`), not
  device captures. Navigation bars render, but there is no device status bar or
  wallpaper. For final App Store screenshots, capture on a real device/simulator
  (or via `fastlane snapshot`) so the status bar and framing are pixel-true.
- The paywall (`08`) is usable as a draft of the IAP screenshot App Review
  requires.
- The weekly review (`05`) uses the deterministic theme fallback (`MockWeeklyReviewProvider`);
  the on-device model produces more natural themes than the raw word-frequency
  fallback shown here.
