# Penwise (code name)

A handwriting coach for iPad and Android tablets. Native app on each platform,
one shared Kotlin Multiplatform engine for letter data and scoring.

The full product plan lives in the "Handwriting App — Development Plan" doc.

## Working on Penwise

- **Back end** (engine, content, data, purchases, ads, privacy): see the folders in the table below.
- **Front end** (screens): read [docs/FRONTEND_HANDOFF.md](docs/FRONTEND_HANDOFF.md) first.
- **Releasing**: [docs/app-store/launch-checklist.md](docs/app-store/launch-checklist.md).

## Repository layout

| Folder | What it holds |
| --- | --- |
| `core/` | Shared engine (Kotlin Multiplatform): ink model, letter templates, scoring |
| `content/templates/` | Letter templates as JSON for three styles (Normal `print-modern`, Classic `cursive-modern`, Traditional `cursive-traditional`), one file per letter, named by Unicode code point (`0061.json` = a) |
| `ios/` | iPad app (SwiftUI + PencilKit). Open `ios/Penwise.xcodeproj` |
| `content/journeys/`, `content/words/` | Courses for each style and the practice word list |
| `ios/Penwise/Learning`, `Commerce`, `Ads`, `Privacy` | Assessment, plan and words; Premium purchases; ads and consent; data deletion |
| `docs/` | Front-end handoff, privacy policy (`docs/privacy`), App Store paperwork (`docs/app-store`) |
| `tools/` | Helper scripts: template generator, Xcode project generator, signing setup |
| `android/` | Coming in Phase 3 |

## Phase 0 status

| Milestone | Status |
| --- | --- |
| 1. Writing canvas on iPad (ruled lines, dotted guide, undo/redo/clear, Pencil-only mode) | Ready to test |
| 2. Recorder (save letter templates and handwriting samples as JSON) | Ready to test |
| 3. Scores on the iPad: Learn, Practice and Test modes using the shared engine | Ready to test (needs Java, see below) |
| 4. Sample test (score 10–20 people's handwriting, tune the engine) | After 3 |

The scoring engine itself is built and covered by 21 automated tests (`core/`).

## Run the iPad app (Mac)

You need: a Mac with Xcode, Java, your iPad, its cable, and your Apple ID. A
free Apple ID is enough for testing on your own iPad.

1. **Install Xcode** from the Mac App Store. Open it once and let it install
   the iOS platform when asked.
2. **Install Java** (needed to build the shared engine). Download the
   **Temurin 21 JDK** for macOS, *aarch64*, as a `.pkg` from
   [adoptium.net](https://adoptium.net/temurin/releases/?os=mac&arch=aarch64&package=jdk)
   and run the installer. Check it in Terminal:
   ```bash
   /usr/libexec/java_home
   ```
   It should print a path. If it prints an error, Java is not installed yet.
3. **Get the code.** In Terminal:
   ```bash
   git clone https://github.com/Panic-Push/handsome.git
   ```
4. **Open the project:** double-click `ios/Penwise.xcodeproj`.
5. **Set up signing:** click the blue *Penwise* project at the top of the left
   sidebar → target *Penwise* → *Signing & Capabilities* → *Team* → *Add an
   Account…* → sign in → pick *(Personal Team)*.
   If Xcode says the bundle identifier is unavailable, change
   `app.penwise.dev` to something unique, such as `app.penwise.dev.yourname`.
6. **Connect the iPad** with the cable, unlock it and tap *Trust*.
7. **Pick the iPad** as the run destination in Xcode's top bar, then press
   **⌘R** (Product › Run).
   The **first build takes 5–15 minutes**: it downloads Gradle and the Kotlin
   compiler for iOS (around 1 GB) and builds the engine. Later builds take
   seconds. Progress shows in Xcode's Report navigator (⌘9).
8. **First run only, on the iPad:**
   - If asked, turn on *Settings › Privacy & Security › Developer Mode* and restart.
   - If the app won't open, go to *Settings › General › VPN & Device
     Management*, tap your Apple ID and choose *Trust*.

With a free Apple ID the app stops opening after 7 days; just press ⌘R again.

### If the build fails

| Message | Fix |
| --- | --- |
| `Java was not found` | Install Java (step 2), then quit and reopen Xcode |
| `xcrun: error` or `xcode-select` | In Terminal: `sudo xcode-select -s /Applications/Xcode.app` |
| `No such module 'PenwiseCore'` | The engine step failed earlier: open the Report navigator (⌘9) and send me the red lines from *Build shared engine (Kotlin)* |
| Anything else | Send me a screenshot of the error |

## What to test

**Letter sessions, digits and sentence scoring**
- [ ] A journey letter opens a session: six tracing exercises checked quietly in place (a score badge pops on each; only a low score shows a tip and asks for another try).
- [ ] After the sixth: a stats screen with the fox, stars, points, average, best, time and all six attempts.
- [ ] Continue goes to training: six groups of the letter (top row traced over faint letters, bottom row written on plain lines) with a progress bar, then stats again, then the next letter.
- [ ] Digits 0–9 exist in all three styles.
- [ ] Sentence worksheet: Finish sentence shows a score, one tip, a score per word, and shape / size / baseline / spacing / smoothness.

**Capitals, letter card and continuous writing**
- [ ] Capitals A–Z exist in Normal, Classic and Traditional; the sentence worksheet draws "Rain taps the roof." with a handwritten R (no typed letters).
- [ ] Tapping a letter on the chapter map opens a card with three worksheet previews (Learn, Practice, Test) instead of the plain action sheet.
- [ ] Practice or Test from the card keeps going through the rest of the course, one letter after another, in order.

**Full lowercase alphabet**
- [ ] Three course books on Home: Normal, Classic and Traditional; each opens a 6-chapter journey covering a–z plus a checkpoint.
- [ ] Every letter a–z appears in Learn, Practice and Test for each style.
- [ ] Traditional letters lean and have loops; Classic letters are upright with plain ascenders. Writing the looped form in Classic (or the plain form in Traditional) is accepted.

**Journey and automatic scoring (section 5)**
- [ ] New learner: Home's journey card says **Start with c** and opens the chapter map (through the entry screen); c shows **Up next**.
- [ ] Returning learner: the card says **Continue with o**, "Round letters · 1 of 4 complete" and "o · Write from memory", and resumes that exact step.
- [ ] Each letter goes Watch → Trace → Write from memory; the header reads e.g. "Round letters · o · Trace".
- [ ] A finished o is scored with **no Check tap** about half a second after you lift the pen.
- [ ] A normal pause before the i dot or t crossbar works; leaving the dot out gives "Add a dot above the stem." with the dot shown in red; adding the dot late re-scores the same try.
- [ ] Undo, Clear, Back and quick taps never leave an old score on screen; ink stays visible when feedback appears.
- [ ] Landscape: the feedback rail sits beside the page (on the left for right-handers, right for left-handers). Portrait: below the page.
- [ ] Map: completed letters show a check and can be reviewed without changing your place; upcoming ones show their order; low scores show **Review**.
- [ ] Checkpoint: four letters from memory (including one that needs work), then a recap with one suggestion and first vs latest tries.
- [ ] All three modes and the journey go through the entry screen with the ad space; Settings › Show ad placeholders off goes straight through.

**Write letters (Milestone 3)**
- [ ] Pick a letter and a mode, write it, tap **Check**: a score from 0 to 100 appears with one tip.
- [ ] **Learn:** trace neatly → 85+. Trace in the wrong direction → the tip says so and the stroke turns red.
- [ ] **Practice:** the letter is faint with no arrows. Write the strokes of **t** in the wrong order → the tip mentions the order.
- [ ] **Test:** no guide (the eye button peeks). Write the letter from memory; size and baseline count.
- [ ] Does the score feel fair? Tell me where it is too strict or too generous.

**Write letters (Milestone 1 basics)**
- [ ] The ruled lines and the dotted letter appear; green numbered dots mark stroke starts, orange arrows show direction.
- [ ] Writing with the Pencil feels smooth with no visible lag.
- [ ] With *Pencil only* on, your palm and finger don't draw. With it off, your finger draws.
- [ ] Undo, redo and clear work; switching letters clears the canvas.
- [ ] The bottom bar shows strokes, points, average pressure, Pencil/Finger and time.
- [ ] Rotating the iPad keeps the letter centred.

**Recorder**
- [ ] Save a *Template* and a *Sample*; both appear in the list.
- [ ] *Share* sends the JSON file (AirDrop to your Mac works well).
- [ ] The files are visible in the Files app under *On My iPad › Penwise*.

Please send back: screenshots, anything that looks wrong, how the pen feels,
and a few recorded samples.

## Shared engine (any computer)

```bash
./gradlew :core:jvmTest
```

Needs Java 17 or newer. The iOS framework (`PenwiseCore.xcframework`) is built
on a Mac in Milestone 3.

## Regenerating files

- Seed letter templates: `python3 tools/make_seed_templates.py`
- Xcode project, after adding or removing Swift files:
  `ruby tools/generate_xcodeproj.rb` (needs `gem install xcodeproj`)
