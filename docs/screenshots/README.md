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
