# Penwise (code name)

A handwriting coach for iPad and Android tablets. Native app on each platform,
one shared Kotlin Multiplatform engine for letter data and scoring.

The full product plan lives in the "Handwriting App — Development Plan" doc.

## Repository layout

| Folder | What it holds |
| --- | --- |
| `core/` | Shared engine (Kotlin Multiplatform): ink model, letter templates, scoring |
| `content/templates/` | Letter templates as JSON, one file per letter, named by Unicode code point (`0061.json` = a) |
| `ios/` | iPad app (SwiftUI + PencilKit). Open `ios/Penwise.xcodeproj` |
| `tools/` | Helper scripts: seed template generator, Xcode project generator |
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

**Workbook redesign**
- [ ] Home: cream paper look; Print / Cursive switch; three mode cards with worksheet previews drawn from the real letter (Learn: dot and arrow, Practice: faint model, Test: blank lines).
- [ ] First visit shows **Start with c**; after writing, it changes to **Continue Practice · lowercase a** (or similar).
- [ ] Cards say "3 of 7 letters practised"; the ad space sits below the cards.
- [ ] Tapping a mode shows the mode screen with the second ad space and **Continue to …**; Back from the letters returns to Home. With *Settings › Show ad placeholders* off, it goes straight to the letters.
- [ ] Writing: the page fills the screen; Letter, Watch again, Undo, Clear and Options are in the top bar; **Check** stays in the same place.
- [ ] After Check: one correction in large text (for example "Bring the bottom of the o down to the baseline", with the baseline turned red). **Try again** is the main button; the score is under **Details**.
- [ ] After a retry: your first try appears dotted grey, with a note such as "Your new o sits on the baseline."
- [ ] Practice: **Try with less guide** switches to lines only. Test: the target letter is in the corner; peeking marks the try **With hint**.
- [ ] Options: Large writing size and Left hand move the letter and make room for your palm.
- [ ] Cursive: c o a d l t i in cursive, with lead-ins and exit strokes.

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
