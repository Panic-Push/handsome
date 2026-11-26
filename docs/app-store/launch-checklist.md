# Launch checklist

Tick these off in order. Items marked (you) need your accounts.

## Accounts and setup

- [ ] (you) Join the Apple Developer Program ($99/year) and run `tools/setup_signing.sh YOURTEAMID your.bundle.id`.
- [ ] (you) Choose the final bundle ID (for example `app.penwise.ios`) and create the app in App Store Connect.
- [ ] (you) Sign the Paid Applications agreement and add banking and tax details (needed before purchases work).
- [ ] (you) Create the three in-app purchases from `listing.md`, with the exact product IDs.
- [ ] (you) Create an AdMob account, add the iOS app, and create two banner units (Home, Entry).
- [ ] Put the real AdMob app ID and unit IDs in `ios/Config/Info.plist` (`GADApplicationIdentifier`, `PenwiseAdUnitHomeBanner`, `PenwiseAdUnitEntry`). Debug builds keep using test ads.
- [ ] (you) In AdMob › Privacy & messaging, create a GDPR consent message (EEA/UK) and an IDFA explainer message.
- [ ] (you) In AdMob, set the app's max ad content rating to "Teen" and turn on "Treatment for users under the age of consent" handling.
- [ ] (you) Add `app-ads.txt` to your website once the app is live (AdMob shows the line to add).

## Privacy and legal

- [ ] Add a contact email to `docs/privacy/index.md` and `index.html` (replace `[CONTACT EMAIL]`).
- [ ] (you) Turn on GitHub Pages for the repo (Settings › Pages › branch `main`, folder `/docs`), so the privacy policy is live at the URL in `AppLinks`. Or host it elsewhere and update `AppLinks.privacyPolicy`.
- [ ] Fill in App Privacy (`privacy-labels.md`) and the age rating (`listing.md`).
- [ ] Decide on Sign in with Apple for version 1 (see `review-notes.md`).

## Product

- [ ] Front end: first-launch age question, assessment, report, plan, words, paywall and Settings rows (see `docs/FRONTEND_HANDOFF.md`).
- [ ] Real app icon (1024 × 1024) and launch look.
- [ ] Test on a real iPad: purchases (sandbox), Restore, ads (test units), consent form (use a VPN to an EU country or AdMob's debug geography), Delete all my data.
- [ ] Sample test: 10–20 people write with the app; tune pass marks and tips.

## Release

- [ ] Archive in Xcode (Product › Archive) and upload to App Store Connect.
- [ ] TestFlight: internal testers first, then up to 10,000 external testers (needs a short beta review).
- [ ] Screenshots and description from `listing.md`.
- [ ] Submit for review with the notes in `review-notes.md`.
