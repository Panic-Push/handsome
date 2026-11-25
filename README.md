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
| 3. First score on the iPad (link the shared engine into the app) | Next |
| 4. Sample test (score 10–20 people's handwriting, tune the engine) | After 3 |

The scoring engine itself is built and covered by 21 automated tests (`core/`).

## Run the iPad app (Mac)

You need: a Mac with Xcode, your iPad, its cable, and your Apple ID. A free
Apple ID is enough for testing on your own iPad.

1. **Install Xcode** from the Mac App Store. Open it once and let it install
   the iOS platform when asked.
2. **Get the code.** In Terminal:
   ```bash
   git clone <this repository's URL>
   ```
3. **Open the project:** double-click `ios/Penwise.xcodeproj`.
4. **Set up signing:** click the blue *Penwise* project at the top of the left
   sidebar → target *Penwise* → *Signing & Capabilities* → *Team* → *Add an
   Account…* → sign in → pick *(Personal Team)*.
   If Xcode says the bundle identifier is unavailable, change
   `app.penwise.dev` to something unique, such as `app.penwise.dev.yourname`.
5. **Connect the iPad** with the cable, unlock it and tap *Trust*.
6. **Pick the iPad** as the run destination in Xcode's top bar, then press
   **⌘R** (Product › Run).
7. **First run only, on the iPad:**
   - If asked, turn on *Settings › Privacy & Security › Developer Mode* and restart.
   - If the app won't open, go to *Settings › General › VPN & Device
     Management*, tap your Apple ID and choose *Trust*.

With a free Apple ID the app stops opening after 7 days; just press ⌘R again.

## What to test (Milestones 1 and 2)

**Trace letters**
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
