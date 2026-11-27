# Penwise front-end handoff

This is the guide for building Penwise's screens on top of the finished
back end. **The back end owns the logic and data; the front end owns how it
looks.** Read this before changing any Swift.

## Ground rules

| Rule | Why |
|---|---|
| Work on the `main` branch. Pull before you start, push small commits. | One shared history; fewer conflicts. |
| **Do not edit `ios/Penwise.xcodeproj/project.pbxproj` by hand.** After adding or removing Swift files run `ruby tools/generate_xcodeproj.rb` (needs `gem install xcodeproj`). | The generator owns packages, resources and build settings. Hand edits get overwritten. |
| Don't choose a signing team in Xcode. Run `tools/setup_signing.sh YOURTEAMID` once. | Keeps `project.pbxproj` identical for everyone. |
| Don't change files under `core/`, `content/`, `ios/Penwise/Engine`, `Learning`, `Commerce`, `Ads`, `Privacy`, `Storage`, `Journey`. Ask for an API change instead. | Back-end territory; covered by tests. |
| Screens live in `ios/Penwise/Screens` and `ios/Penwise/Components`. Everything in `Screens/Starter` is a plain placeholder meant to be replaced. | Clear ownership. |
| Keep Penwise's own look (paper, ink, fox). Don't copy another app's art or layout. | App Store and copyright. |

## Navigation

`HomeView` owns a `NavigationStack(path:)` of `Route` values
(`Screens/Route.swift`). Push a route with `path.append(...)`. New routes:

| Route | Opens | Starter screen |
|---|---|---|
| `.assessment` | The 3-minute handwriting check | `AssessmentView` |
| `.report` | The latest report | `ReportView` |
| `.assessment` after a check | Suggested daily practice | `PracticeSuggestions` |
| `.words(WordRequest)` | A run of practice words | `WordPracticeView` |
| `.paywall` | Penwise Premium | `PaywallView` |

## 1. Starting assessment (`Learning/AssessmentSession.swift`)

```swift
@StateObject var session = AssessmentSession(style: settings.style)
```

| Use | What it gives |
|---|---|
| `session.current?.prompt` | Text to show ("Write a lowercase g."). |
| `session.layout(in: canvasSize)` | `GuideLayout` for drawing `RuledLinesView` **and** converting ink. |
| `session.submit(strokes: ink.capturedStrokes(in: layout), seconds:, finger: ink.lastInkUsedFinger)` | Scores the task and moves on. `seconds` = first touch to last lift (negative if unknown). |
| `session.skip()` | Leaves a task out. |
| `session.progress`, `index`, `tasks.count` | For a progress bar. |
| `session.lastScore` | Optional quiet tick after each task. Don't celebrate each task. |
| `session.report` | Non-nil when finished; already saved to `PlanStore`. |

Show a calm, test-like screen: no guides beyond the ruled lines and no score per task.

## 2. Report and plan (`Learning/PlanStore.swift`, `Engine/LearningBridge.swift`)

`PlanStore.shared` (ObservableObject):

| Property / method | Meaning |
|---|---|
| `needsAssessment` | True until the first check. Home should invite the check. |
| `report: HandwritingReport?` | `overall`, `summary`, `skills` (weakest first: `title`, `score`, `advice`), `focusTitles`, `strengthTitles`, `weakLetters`, `lettersPerMinute`, `date`. |
| `history` | Older reports, oldest first, for a progress chart. |
| `today: PlanDay?` | `minutes`, `focus`, `items: [PlanItem]`. |
| `PlanItem` | `title`, `detail`, `minutes`, `kind` (`.letterLesson/.letterPractice/.letterTest/.words/.sentence`), `letters`, `focus`. |
| `minutesPerDay` (settable; `PlanStore.minuteChoices`) | Changes today's plan immediately. |
| `isDone(item)`, `progressToday` | Ticks. |
| `markDone(item)` | Call when an activity is finished. Word runs tick themselves. |
| `route(for: item, style:)` | The `Route` to push for an item. |
| `reassessmentDue` | Invite a new check (every 14 days). |
| `refresh()` | Already called when the app becomes active. |

## 3. Words (`Learning/WordSession.swift`)

```swift
@StateObject var session = WordSession(request: request)  // from .words(request)
```

| Use | What it gives |
|---|---|
| `session.word`, `session.traced` | The word; the first two are traced over a faint model. |
| `session.plan` | `LinePlan`: `templates[i]` drawn at `xs[i]` (line units). Draw each with `TemplateOverlay` using a layout shifted by `xs[i] * unit`. |
| `session.layout(in:)` | Guides and ink conversion. |
| `session.request.focus` | `"BASELINE"`: highlight `[1.0]`; `"SIZE"`: highlight `[0.5]` in `RuledLinesView`. |
| `submit(strokes:finger:)` → `LineResult` | `overall`, `tip`, `parts`, `words`, `letterScores`. Show it quietly near the word. |
| `retry()`, `next()`, `isFinished`, `average`, `best`, `progress` | Flow and summary. |

Automatic checking (like the lesson screen) is welcome: wait about 1.4 s after
the last lift, and only if the ink spans most of the word.

## 4. Premium (`Commerce/StoreService.swift`, `Commerce/FeatureGate.swift`)

`StoreService.shared` (@MainActor ObservableObject):

| Use | What it gives |
|---|---|
| `products` | Yearly, monthly, lifetime (`Product`): `displayName`, `displayPrice`. |
| `offerText(for:)` | "7 days free, then $14.99/year (US, eligible yearly subscriber)". |
| `purchase(product)` async → `.purchased / .pending / .cancelled / .failed(text)` | |
| `restore()` async | **A visible Restore button is required by App Review.** |
| `isPremium`, `activeProductID`, `lastError` | |

`FeatureGate` (call before opening; show `.paywall` when false):

| Call | Rule |
|---|---|
| `canOpen(chapterIndex:style:)` | Normal: all free. Classic and Traditional: chapter 1 free. |
| `canOpen(planItemAt:)` | The first plan item each day is free. |
| `canStart(.test / .words / .sentence)` + `recordUse(...)` | 3 tests, 3 word runs, 1 sentence a day free. |
| `remainingToday(...)` | For "2 left today" labels. |

**The paywall must show** each option's price and period, the free-trial
terms, Restore, and links to the privacy policy and terms (`AppLinks`). It
also needs the auto-renew sentence, as in the starter screen.

## 5. Ads (`Ads/AdsService.swift`, `Components/AdSlot.swift`)

- Use `AdSlot(placement: .home)` under the Home mode cards and
  `AdSlot(placement: .modeEntry)` on the entry screen. **Nowhere else.**
- `AdSlot.shouldAppear` decides whether to route through the entry screen and
  whether to reserve the Home space. It is false for Premium.
- `AdsService.shared.start()` is already called at launch (consent form, then
  Apple's tracking prompt for adults, then the SDK).
- Settings must show **Privacy choices** when `AdsService.shared.privacyOptionsRequired`
  (it calls `showPrivacyOptions()`).

## 6. Age and privacy

- Onboarding derives an age category from birth year and, where necessary, birthday status. Minors and unknown ages receive no ads or tracking prompts.
- Settings includes **Delete all my data** (confirmation, then
  `AccountService.deleteAllData()`), the privacy policy link, and Restore.
  The starter Settings rows show the minimum.

## 7. Screens to build (suggested)

1. **First launch:** welcome, age question, style choice, then "Take the 3-minute check" (or skip).
2. **Assessment:** calm full-screen writing, progress bar, no per-task scores.
3. **Report:** score, one-sentence summary, skills chart (weakest first), letters to practise, speed. "See my plan".
4. **Home:** today's plan card (progress ring, next activity) above the journey card. Invite a re-check when due.
5. **Plan:** today's activities with ticks, minutes picker, locks with the paywall for Premium items.
6. **Word practice:** the model-1 style sheet (progress bar, quiet scores, stats at the end).
7. **Paywall** and **Settings** (Premium, privacy, delete data).

## Testing purchases

Run from Xcode: the scheme uses `ios/Config/Penwise.storekit`, so purchases
work without App Store Connect. Xcode's *Debug › StoreKit › Manage
Transactions* can refund or expire them.
