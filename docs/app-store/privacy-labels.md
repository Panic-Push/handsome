# App Privacy answers (App Store Connect › App Privacy)

Penwise itself collects nothing off the device. The Google Mobile Ads SDK
does, so the answers below describe AdMob's collection in the adult, ad-supported experience.
Check Google's current guidance before submitting:
https://developers.google.com/admob/ios/privacy/data-disclosure

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Collected | Linked to user | Used for tracking | Purposes |
|---|---|---|---|---|
| Identifiers › Device ID (advertising identifier) | Yes, only if the user allows tracking | No | Yes | Third-party advertising |
| Usage Data › Advertising Data | Yes | No | Yes | Third-party advertising, Analytics |
| Diagnostics › Crash Data, Performance Data | Yes | No | No | Analytics |
| Location › Coarse Location (from IP) | Yes | No | Yes | Third-party advertising |
| Contact Info › Name, Email | **No**: kept on device only | | | |
| User Content › handwriting | **No**: kept on device only | | | |
| Purchases | **No**: handled by Apple | | | |

Tracking: **Yes** (ads may be personalised for adults who allow tracking).
Only confirmed adults on the free plan enter the consent flow. Minors and people who skip the age question see no ads. The entered birth year is discarded after classification. At submission, inspect the Xcode archive privacy report, including the embedded Google SDK manifests.
