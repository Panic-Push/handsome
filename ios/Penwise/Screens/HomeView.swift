import SwiftUI
import Lottie

/// Home tells the learner what to write next: the journey card first, then
/// Learn, Practice and Test as direct routes, then the banner ad.
struct HomeView: View {
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journeys = JourneyStore.shared
    @State private var path: [Route] = []
    @State private var greeting = 0
    private let greetings: [FoxPose] = [.hello, .tap, .sneeze, .pencilBonk, .dizzy, .sleepy, .happy]

    @AppStorage("penwise.welcome.workbook.v2") private var sawWelcome = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingWelcome = false
    @State private var showingStreak = false
    @State private var transitionID = UUID()
    @State private var transitionFox: FoxPose?
    @State private var showSettings = false

    @State private var earnedStreakDay = false

    private let library = TemplateLibrary.shared

    private var journey: Journey? { JourneyLibrary.shared.journey(style: settings.style) }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let compact = geo.size.width < 540
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if let journey {
                            journeyCard(journey)
                        }
                        courseShelf(compact: compact)
                        modeShortcuts
                        Button("Your practice plan") { path.append(.assessment) }
                            .buttonStyle(.bordered)
                        AdSlot(placement: .home).frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 1180)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { path.append(.assessment) } label: {
                        Label("Writing check", systemImage: "pencil.line").labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Label("My workbook", systemImage: "book.closed").labelStyle(.titleAndIcon)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: Route.self) { route in
                destination(route)
            }
        }
        .tint(Color.courseAccent)
        .overlay {
            if let pose = transitionFox, !reduceMotion,
               let animation = LottieAnimation.asset("fox_" + pose.rawValue) {
                let id = transitionID
                GeometryReader { geometry in
                    LottieView(animation: animation).resizable()
                        .playing()
                        .animationSpeed(1.25)
                        .animationDidFinish { completed in
                            guard transitionID == id else { return }
                            transitionFox = nil
                            if completed && pose == .peek { showEarnedStreakAtHome() }
                        }
                        .aspectRatio(animation.bounds.width / animation.bounds.height, contentMode: pose == .dash ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea().id(id)
                .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .onChange(of: progress.attemptsToday) { old, new in
            if old == 0 && new > 0 { earnedStreakDay = true }
        }
        .onChange(of: path) { old, new in
            if reduceMotion && new.isEmpty { showEarnedStreakAtHome() }
            transitionID = UUID()
            if reduceMotion || old.isEmpty == new.isEmpty {
                transitionFox = nil
            } else {
                transitionFox = new.isEmpty ? .peek : .dash
            }
        }
        .onAppear {
            if !sawWelcome { showingWelcome = true }
        }
        .onChange(of: sawWelcome) { _, seen in
            if !seen { showingWelcome = true }
        }
        .fullScreenCover(isPresented: $showingWelcome, onDismiss: {
            Task { await AdsService.shared.start() }
        }) {
            WorkbookWelcome(style: $settings.style) {
                sawWelcome = true
                showingWelcome = false
            }
        }
        .sheet(isPresented: $showingStreak) {
            streakCard.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }

    private func showEarnedStreakAtHome() {
        guard path.isEmpty, earnedStreakDay else { return }
        earnedStreakDay = false
        showingStreak = true
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .entry(let target):
            EntryView(target: target, path: $path)
        case .letters(let mode):
            LetterPickerView(mode: mode)
        case .sentences(let style, let mode, let glyph):
            SentenceWorksheet(style: style, mode: mode, focus: glyph)
        case .write(let mode, let templateID):
            WorksheetView(context: .free(mode, templateID), path: $path)
        case .set(let mode, let title, let ids, let shuffled):
            WorksheetView(context: .set(mode, title, ids, shuffled: shuffled), path: $path)
        case .journeyMap(let id):
            JourneyMapView(journeyID: id, path: $path)
        case .lesson(let position, let review):
            if JourneyLibrary.shared.journey(id: position.journeyID)?.chapter(position.chapterID)?.isCheckpoint == true {
                WorksheetView(context: .lesson(position, review: review), path: $path)
            } else {
                LetterSessionView(position: position, review: review, path: $path)
            }
        case .recap(let id):
            CheckpointRecapView(journeyID: id, path: $path)
        case .recorder:
            RecorderView()
        case .assessment:
            AssessmentView(style: settings.style, path: $path)
        case .report:
            ReportView()
        case .words(let request):
            WordPracticeView(request: request)
        case .paywall:
            PaywallView()
        }
    }

    /// Goes through the entry (ad) screen when an ad is available, straight to
    /// the destination otherwise. Extra taps while navigating are ignored.
    private func go(_ target: EntryTarget) {
        guard path.isEmpty else { return }
        path.append(AdSlot.shouldAppear ? .entry(target) : target.destination)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                greeting = (greeting + 1) % greetings.count
            } label: {
                WorkbookFox(pose: greetings[greeting]).frame(width: 76, height: 76)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play with the Penwise fox")
            Text("Penwise")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
            Spacer()
            Button { showingStreak = true } label: {
                HStack(spacing: 12) {
                    Label("\(progress.streak)", systemImage: "flame.fill")
                        .foregroundStyle(Color.orange)
                    Divider().frame(height: 18)
                    Text("\(progress.attemptsToday) today")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .paperCard(radius: 14)
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(progress.streak) day streak, \(progress.attemptsToday) letters today")
        }
    }

    private var streakCard: some View {
        ScrollView {
            VStack(spacing: 18) {
                WorkbookFox(pose: progress.streak > 0 ? .happy : .hello).frame(height: 112)
                Text(progress.streak == 0 ? "Start your writing streak" : "\(progress.streak)-day writing streak")
                    .font(.workbook(.largeTitle))
                Text("Finish a scored exercise to mark a practice day.").font(.body)
                HStack {
                    ForEach(-6...0, id: \.self) { offset in
                        let day = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                        let wrote = progress.practiced(on: day)
                        VStack {
                            Image(systemName: wrote ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(wrote ? Color.courseAccent : .secondary)
                            Text(day, format: .dateTime.weekday(.narrow))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted) + (wrote ? ", practiced" : ", no practice"))
                    }
                }.padding().paperCard()
                Button("Continue") { showingStreak = false }.buttonStyle(LessonActionStyle())
            }
            .padding(28)
        }
    }

    // MARK: - Journey card

    private func journeyCard(_ journey: Journey) -> some View {
        let finished = journeys.isFinished(journey)
        let p = journeys.position(in: journey)
        let chapter = journey.chapter(p.chapterID) ?? journey.chapters[0]
        let chapterLetters = journeys.letters(chapter, in: journey)
        let glyph = p.letterIndex < chapterLetters.count ? chapterLetters[p.letterIndex] : (chapterLetters.first ?? "")
        let done = journeys.completedCount(chapter, in: journey)
        return Button {
            path.append(.journeyMap(journey.id))
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(journey.title)
                        .font(.workbook(.largeTitle, weight: .bold))
                    Text("\(chapter.title) · \(done) of \(chapterLetters.count) complete")
                        .font(.headline)
                    ProgressView(value: Double(done), total: Double(max(1, chapterLetters.count)))
                        .tint(.white)
                    Label(finished ? "Review course" : journeys.hasStarted(journey) ? "Continue with \(glyph)" : "Start with \(glyph)", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.black)
                        .background(.white, in: Capsule())
                }
                Spacer(minLength: 0)
                WorkbookFox(pose: .idle)
                    .frame(minWidth: 60, idealWidth: 140, maxWidth: 150, maxHeight: 160)
            }
            .padding(24)
            .foregroundStyle(.white)
            .background(Color.courseFill, in: RoundedRectangle(cornerRadius: 26))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private func courseShelf(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your courses").font(.workbook(.title))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: compact ? 1 : 3), spacing: 14) {
                ForEach(LetterStyle.allCases) { style in
                    if let course = JourneyLibrary.shared.journey(style: style) {
                        courseCover(style, course: course)
                    }
                }
            }
        }
    }

    private func courseCover(_ style: LetterStyle, course: Journey) -> some View {
        let color: Color = {
            switch style {
            case .print: return .courseApricot
            case .cursive: return .courseMint
            case .traditional: return .courseRose
            }
        }()
        let position = journeys.position(in: course)
        let chapters = course.chapters.filter { !$0.isCheckpoint }
        let total = chapters.reduce(0) { $0 + $1.letters.count }
        let completed = chapters.reduce(0) { $0 + journeys.completedCount($1, in: course) }
        return Button {
            settings.style = style
            path.append(.journeyMap(course.id))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(style.title).font(.workbook(.largeTitle, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                HStack(spacing: 3) {
                    ForEach(["a", "l", "g"].compactMap { library.template(id: course.templateID($0)) }) { template in
                        LetterThumbnail(template: template, lineWidth: 3, color: .ink)
                            .frame(maxWidth: 62)
                    }
                }
                .frame(height: 72)
                if let chapter = course.chapter(position.chapterID) {
                    Text(chapter.title).font(.headline)
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        .tint(Color.courseAccent)
                    Text("\(completed) of \(total) course letters complete")
                        .font(.subheadline)
                }
            }
            .padding(20)
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.ink.opacity(0.12)).frame(width: 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(Color.ink)
        }
        .buttonStyle(PressableStyle())
    }

    private var modeShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(settings.style.title) shortcuts").font(.workbook(.headline))
            HStack {
                ForEach(WritingMode.selectable) { mode in
                    Button { go(.mode(mode)) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                            Text(mode.rawValue).font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

private struct WorkbookWelcome: View {
    @Binding var style: LetterStyle
    let finish: () -> Void
    private enum Step: Int, CaseIterable { case welcome, intention, experience, workbook, age, label }
    @State private var step: Step = .welcome
    @ObservedObject private var plans = PlanStore.shared
    @AppStorage("penwise.intention") private var intention = "Everyday notes"
    @AppStorage("penwise.experience") private var experience = "Starting out"
    @AppStorage("penwise.workbook.label") private var workbookName = ""
    @State private var year: Int?
    @State private var birthdayPassed: Bool?
    private var currentYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }
    private var boundary: Bool { year == currentYear - 18 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                    .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                Image("FoxMark")
                    .resizable().scaledToFit().frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 23))
                    .accessibilityHidden(true)
                switch step {
                case .welcome:
                    Text("Welcome to Penwise").font(.workbook(.largeTitle))
                    Text("Trace a letter, write it from memory, and see where your penmanship improves.")
                    next("Set up my workbook", .intention)
                    Button("Skip introduction") { step = .age }
                case .intention:
                    Text("What brings you to the page?").font(.workbook(.largeTitle))
                    choices(["Everyday notes", "School or study", "Cursive writing"], selection: $intention)
                    next("Continue", .experience)
                case .experience:
                    Text("How does writing feel?").font(.workbook(.largeTitle))
                    choices(["Starting out", "Getting comfortable", "Fine-tuning my writing"], selection: $experience)
                    Text(experience == "Starting out" ? "Tracing shows you where each stroke begins." :
                         experience == "Getting comfortable" ? "Practice lets you try each letter with a lighter guide." :
                         "Test lets you write from memory and compare your scores.")
                    next("Continue", .workbook)
                case .workbook:
                    Text("Choose your workbook").font(.workbook(.largeTitle))
                    ForEach(LetterStyle.allCases) { option in
                        Button { style = option } label: {
                            HStack {
                                if let letter = TemplateLibrary.shared.template(id: "latin.\(option.rawValue).a") {
                                    LetterThumbnail(template: letter).frame(width: 48, height: 48)
                                }
                                Text(option.title)
                                Spacer()
                                Image(systemName: option == style ? "checkmark.circle.fill" : "circle")
                            }.padding(12).paperCard(radius: 16)
                        }.buttonStyle(.plain).accessibilityAddTraits(option == style ? .isSelected : [])
                    }
                    Picker("Daily practice goal", selection: $plans.minutesPerDay) {
                        ForEach(PlanStore.minuteChoices, id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    next("Continue", .age)
                case .age:
                    Text("What year were you born?").font(.workbook(.largeTitle))
                    Text("Penwise uses your answer to set age-appropriate privacy settings. Only your age group is saved on this iPad.")
                    Picker("Birth year", selection: $year) {
                        Text("Choose a year").tag(nil as Int?)
                        ForEach(Array((currentYear-120...currentYear).reversed()), id: \.self) {
                            Text(String($0)).tag(Optional($0))
                        }
                    }.onChange(of: year) { _, _ in birthdayPassed = nil }
                    if boundary {
                        Picker("Has your birthday happened this year?", selection: $birthdayPassed) {
                            Text("Choose an answer").tag(nil as Bool?)
                            Text("Yes").tag(Optional(true))
                            Text("No").tag(Optional(false))
                        }
                    }
                    next("Continue", .label).disabled(year == nil || (boundary && birthdayPassed == nil))
                    Button("Prefer not to say") { year = nil; birthdayPassed = nil; step = .label }
                case .label:
                    Text("Name your workbook").font(.workbook(.largeTitle))
                    TextField("Workbook name (optional)", text: $workbookName).textFieldStyle(.roundedBorder)
                    Text("Your letters, scores and practice plan stay on this iPad.")
                    Button("Open my workbook") {
                        AppSettings.shared.ageBand = AgeBand.classify(birthYear: year, currentYear: currentYear, birthdayPassed: birthdayPassed)
                        finish()
                    }.buttonStyle(LessonActionStyle())
                }
                if let previous = Step(rawValue: step.rawValue - 1) { Button("Back") { step = previous } }
            }
            .padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(Color.paper).interactiveDismissDisabled()
    }

    private func next(_ title: String, _ destination: Step) -> some View {
        Button(title) { step = destination }.buttonStyle(LessonActionStyle())
    }

    private func choices(_ options: [String], selection: Binding<String>) -> some View {
        ForEach(options, id: \.self) { value in
            Button { selection.wrappedValue = value } label: {
                HStack {
                    Text(value)
                    Spacer()
                    Image(systemName: selection.wrappedValue == value ? "checkmark.circle.fill" : "circle")
                }.padding().paperCard(radius: 16)
            }.buttonStyle(.plain).accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
        }
    }
}
