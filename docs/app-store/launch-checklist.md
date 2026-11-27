# Penwise release checklist

## Current build

- Xcode Run uses Debug, Google's test ads and the local StoreKit catalogue. Release uses the Penwise AdMob app ID and the two placement IDs. The bundle ID is `app.penwise.dev`.
- Onboarding, local workbook, age screening, handwriting check, report, suggested practice, words, paywall, restore and data deletion are available in the app.
- The privacy policy is bundled for offline reading and published from `docs/privacy/`. Contact is penwise.dev@gmail.com.
- For free hosting, select Settings → Pages → Deploy from a branch → main → /docs. Verify https://panic-push.github.io/handsome/privacy/ opens without signing in before entering it in App Store Connect.

## Before distribution

- Confirm the final bundle ID and signing team, register the app, and complete Apple’s paid applications, tax and banking setup.
- Set the three products and storefront prices from listing.md in App Store Connect. Set India explicitly. Enable the one-week introductory offer only for the annual subscription.
- Configure Google's European consent message, regional privacy messages and appropriate ad content rating in AdMob. Verify app ownership and app-ads.txt according to the account instructions.
- Use an iPad and sandbox purchases to test eligible and returning subscribers, restore, renewals, monthly, lifetime, cancellations and data deletion. Verify gated ads for under-18, skipped age, adult with ATT declined or granted, and Premium. Test consent changes and banner no-fill.
- Enter App Privacy answers from the release archive and SDK disclosures, complete the age questionnaire, add iPad screenshots, the public privacy URL and standard EULA link.
- Archive and upload a signed build to TestFlight before submitting for review.
