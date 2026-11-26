import Lottie
import SwiftUI
import UIKit

/// A full lesson for one letter of the journey, as one continuous session:
///
/// 1. Tracing: six exercises of the letter (three with arrows, three faint).
///    Each is checked quietly in place; only a low score shows a tip.
/// 2. Stats: stars, scores, time and the six attempts, with the fox.
/// 3. Training: six groups of the letter (one row traced, one row written
///    on plain lines), with a progress bar.
/// 4. Stats again, then straight on to the next letter.
struct LetterSessionView: View {
    private enum Stage { case tracing, tracingStats, training, trainingStats }

    private enum Guide { case learn, faint, lines }

    private struct Item {
        let plan: LinePlan
        let guide: Guide
    }

    private struct Outcome {
        var strokes: [CapturedStroke]
        var score: Int
    }

    /// Pause after a lift before checking; longer while more strokes are likely.
    private static let pause: TimeInterval = 0.6
    private static let longPause: TimeInterval = 1.2
    private static let groupPause: TimeInterval = 1.4
    /// An exercise passes at this score, or after this many tries.
    private static let passScore = 65
    private static let maxTries = 3

    @Binding var path: [Route]
    private let review: Bool

    @StateObject private var ink = InkModel()
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journeys = JourneyStore.shared
    @ObservedObject private var progress = ProgressStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var position: LessonPosition
    @State private var stage: Stage = .tracing
    @State private var items: [Item] = []
    @State private var outcomes: [Outcome] = []
    @State private var tries = 0
    @State private var totalTries = 0
    @State private var stageStart = Date()
    @State private var stageSeconds: TimeInterval = 0
    @State private var sheetSize: CGSize = .zero
    @State private var tip: String?
    @State private var failedStrokes: [CapturedStroke] = []
    @State private var problemStrokes: Set<Int> = []
    @State private var checking = false
    @State private var pending: DispatchWorkItem?
    @State private var token = UUID()
    @State private var demoStart: Date?
    @State private var justPassed: Int?
    @State private var celebrationStart: Date?

    private let library = TemplateLibrary.shared

    init(position: LessonPosition, review: Bool, path: Binding<[Route]>) {
        _path = path
        _position = State(initialValue: position)
        self.review = review
    }

    // MARK: - Derived

    private var journey: Journey? { JourneyLibrary.shared.journey(id: position.journeyID) }
    private var chapter: Journey.Chapter? { journey?.chapter(position.chapterID) }

    private var glyph: String {
        guard let j = journey, let c = chapter else { return "" }
        let letters = journeys.letters(c, in: j)
        return letters.indices.contains(position.letterIndex) ? letters[position.letterIndex] : ""
    }

    private var style: LetterStyle { LetterStyle(rawValue: journey?.style ?? "") ?? .print }
    private var templateID: String { journey?.templateID(glyph) ?? "" }
    private var template: LetterTemplate? { library.template(id: templateID) }
    private var current: Int { outcomes.count }
    private var isTraining: Bool { stage == .training || stage == .trainingStats }
    private var color: Color { isTraining ? WritingMode.practice.color : WritingMode.learn.color }

    private var stageTitle: String { isTraining ? "Training" : "Tracing" }

    private var instruction: String {
        guard current < items.count else { return "" }
        switch items[current].guide {
        case .learn: return "Trace the \(glyph) from the green dot, following the arrow."
        case .faint: return isTraining ? "Trace the \(glyph)\(glyph)\(glyph) over the faint letters." : "Trace the faint \(glyph)."
        case .lines: return "Now write \(glyph)\(glyph)\(glyph) on your own."
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            sheet
                .padding(.horizontal, 20)
            footer
        }
        .background(Color.paper.ignoresSafeArea())
        .overlay {
            if stage == .tracingStats || stage == .trainingStats {
                statsScreen
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: start)
        .onDisappear(perform: cancelPending)
        .onChange(of: ink.revision) { _, _ in inkChanged() }
        .onChange(of: ink.isDrawing) { _, drawing in drawingChanged(drawing) }
        .onChange(of: ink.pencilOnly) { _, value in settings.pencilOnly = value }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { leave() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Color.paperCard, in: Circle())
                    .overlay(Circle().stroke(Color.cardBorder))
            }
            .accessibilityLabel("Close lesson")

            VStack(alignment: .leading, spacing: 2) {
                Text("\(chapter?.title ?? "") · \(glyph)")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(stageTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 150, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: max(14, geo.size.width * CGFloat(current) / CGFloat(max(items.count, 1))))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
                }
            }
            .frame(height: 14)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(current) of \(items.count)")

            if !isTraining {
                Button { replayDemo() } label: {
                    Image(systemName: "play.circle").font(.title2).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Watch again")
            }
            Button { ink.undo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.title3).frame(width: 44, height: 44)
            }
            .disabled(ink.strokeCount == 0)
            .accessibilityLabel("Undo")
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Sheet

    private func cell(_ index: Int, in size: CGSize) -> (frame: CGRect, layout: GuideLayout) {
        let columns = 3
        let w = size.width / CGFloat(columns)
        let h = size.height / 2
        let frame = CGRect(x: CGFloat(index % columns) * w, y: CGFloat(index / columns) * h, width: w, height: h)
            .insetBy(dx: 6, dy: 6)
        let width = items.indices.contains(index) ? items[index].plan.width : 0.5
        let large: CGFloat = settings.size == .large ? 1.0 : 0.85
        let unit = max(30, min(frame.height / 1.9, frame.width / (width + 0.5)) * large)
        let origin = CGPoint(x: frame.midX - width * unit / 2, y: frame.midY - 0.75 * unit)
        return (frame, GuideLayout(origin: origin, unit: unit))
    }

    private var sheet: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(items.indices, id: \.self) { index in
                    cellView(index, in: geo.size)
                }
                if let start = demoStart, current < items.count, let template, !isTraining {
                    StrokeDemoView(template: template, layout: cell(current, in: geo.size).layout,
                                   start: start, color: color)
                }
                InkCanvas(model: ink)
                if let start = celebrationStart {
                    ConfettiView(start: start)
                }
            }
            .onAppear { sheetSize = geo.size }
            .onChange(of: geo.size) { _, newSize in
                sheetSize = newSize
                restartItem()
            }
        }
        .background(Color.paperCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.cardBorder))
    }

    @ViewBuilder
    private func cellView(_ index: Int, in size: CGSize) -> some View {
        let c = cell(index, in: size)
        let item = items[index]
        let isActive = index == current
        let done = index < outcomes.count
        ZStack(alignment: .topLeading) {
            CellRules(frame: c.frame, layout: c.layout)
            if done {
                InkReplay(strokes: outcomes[index].strokes, layout: c.layout, color: .ink)
            } else {
                ForEach(item.plan.templates.indices, id: \.self) { k in
                    letterGuide(item, letter: k, layout: shifted(c.layout, by: item.plan.xs[k]),
                                active: isActive, highlight: isActive && k == 0 ? problemStrokes : [])
                }
                if isActive && !failedStrokes.isEmpty {
                    InkReplay(strokes: failedStrokes, layout: c.layout, color: .orange.opacity(0.45))
                }
            }
            if isActive {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color, lineWidth: 3)
                    .frame(width: c.frame.width, height: c.frame.height)
                    .offset(x: c.frame.minX, y: c.frame.minY)
            }
            if done {
                scoreBadge(outcomes[index].score, pop: justPassed == index)
                    .offset(x: c.frame.minX + 10, y: c.frame.minY + 10)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func letterGuide(_ item: Item, letter k: Int, layout: GuideLayout, active: Bool, highlight: Set<Int>) -> some View {
        let t = item.plan.templates[k]
        let cue = active && k == 0
        switch item.guide {
        case .learn:
            TemplateOverlay(template: t, layout: layout, highlight: highlight)
        case .faint:
            TemplateOverlay(template: t, layout: layout, showArrows: cue, showDots: cue, pathOpacity: 0.22,
                            solidPath: true, highlight: highlight)
        case .lines:
            TemplateOverlay(template: t, layout: layout, showPath: false, showArrows: false,
                            showDots: cue, highlight: highlight)
        }
    }

    private func shifted(_ layout: GuideLayout, by x: CGFloat) -> GuideLayout {
        GuideLayout(origin: CGPoint(x: layout.origin.x + x * layout.unit, y: layout.origin.y), unit: layout.unit)
    }

    private func scoreBadge(_ score: Int, pop: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: score >= ProgressStore.passMark ? "checkmark.circle.fill" : "checkmark.circle")
            Text("\(score)")
        }
        .font(.callout.weight(.bold))
        .foregroundStyle(scoreColor(score))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.paper, in: Capsule())
        .scaleEffect(pop ? 1.15 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pop)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let tip {
                Image(systemName: "lightbulb.fill").foregroundStyle(Color.orange)
                Text(tip)
                    .font(.workbook(.title3))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else if checking {
                ProgressView()
                Text("Checking…").foregroundStyle(.secondary)
            } else {
                Text(instruction)
                    .font(.workbook(.title3))
                    .foregroundStyle(Color.ink)
            }
            Spacer()
            Text("\(min(current + 1, items.count)) of \(items.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(height: 64)
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: tip)
    }

    // MARK: - Stats

    private var average: Int {
        outcomes.isEmpty ? 0 : Int((Double(outcomes.map(\.score).reduce(0, +)) / Double(outcomes.count)).rounded())
    }

    private var best: Int { outcomes.map(\.score).max() ?? 0 }
    private var points: Int { outcomes.map(\.score).reduce(0, +) / 10 + (average >= 80 ? 10 : 0) }

    private var statsScreen: some View {
        let fox = LottieView(animation: .asset("fox_celebrate")).resizable()
        return ZStack {
            LinearGradient(colors: [color.opacity(0.18), Color.paper], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if !reduceMotion, let start = celebrationStart {
                ConfettiView(start: start).ignoresSafeArea()
            }
            ScrollView {
                VStack(spacing: 22) {
                    Group {
                        if reduceMotion { fox } else { fox.looping() }
                    }
                    .frame(width: 170, height: 170)
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text(stage == .tracingStats ? "Tracing complete!" : "Letter \(glyph) complete!")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                        Text("\(chapter?.title ?? "") · \(glyph) · \(stageTitle)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    StarsView(count: ProgressStore.stars(for: average), size: 46, spacing: 10, animated: true)

                    HStack(spacing: 12) {
                        statTile("Points", "+\(points)", symbol: "bolt.fill")
                        statTile("Average", "\(average)", symbol: "chart.bar.fill")
                        statTile("Best", "\(best)", symbol: "trophy.fill")
                        statTile("Time", timeText, symbol: "clock.fill")
                    }
                    .frame(maxWidth: 640)

                    attemptsBoard
                        .frame(maxWidth: 640)

                    Button(action: continueFromStats) {
                        Text(stage == .tracingStats ? "Continue to training" : nextLetterLabel)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: 460, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .controlSize(.large)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var timeText: String {
        let s = Int(stageSeconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var nextLetterLabel: String {
        if review { return "Back to the map" }
        guard let j = journey, let next = nextLetterPosition() else { return "See your recap" }
        let letters = j.chapter(next.chapterID).map { journeys.letters($0, in: j) } ?? []
        let g = letters.indices.contains(next.letterIndex) ? letters[next.letterIndex] : ""
        if j.chapter(next.chapterID)?.isCheckpoint == true { return "Go to the checkpoint" }
        return "Next letter · \(g)"
    }

    private func statTile(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.ink)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .paperCard(radius: 18)
    }

    /// The best attempt large, and all six small, at the scale they were written.
    private var attemptsBoard: some View {
        let bestIndex = outcomes.indices.max { outcomes[$0].score < outcomes[$1].score }
        return HStack(spacing: 14) {
            if let bestIndex {
                VStack(spacing: 6) {
                    attemptThumb(bestIndex).frame(height: 140)
                    Text("Best · \(outcomes[bestIndex].score)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .frame(width: 200)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(outcomes.indices, id: \.self) { i in
                    attemptThumb(i)
                        .frame(height: 64)
                        .overlay(alignment: .bottomTrailing) {
                            Text("\(outcomes[i].score)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(scoreColor(outcomes[i].score))
                                .padding(4)
                        }
                }
            }
        }
        .padding(14)
        .paperCard(radius: 20)
    }

    private func attemptThumb(_ i: Int) -> some View {
        let width = items.indices.contains(i) ? items[i].plan.width : 0.5
        return Canvas { context, size in
            let unit = min(size.height / 1.7, size.width / (width + 0.4))
            let layout = GuideLayout(origin: CGPoint(x: (size.width - width * unit) / 2, y: (size.height - 1.5 * unit) / 2),
                                     unit: unit)
            var base = Path()
            base.move(to: CGPoint(x: 0, y: layout.y(1)))
            base.addLine(to: CGPoint(x: size.width, y: layout.y(1)))
            context.stroke(base, with: .color(Color.rule.opacity(0.6)), lineWidth: 1)
            for stroke in outcomes[i].strokes {
                let pts = stroke.points.map { layout.toScreen(CGPoint(x: $0.x, y: $0.y)) }
                guard pts.count > 1 else { continue }
                var p = Path()
                p.addLines(pts)
                context.stroke(p, with: .color(Color.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Flow

    private func start() {
        ink.pencilOnly = settings.pencilOnly
        if !review { journeys.setPosition(position) }
        beginStage(.tracing)
    }

    private func beginStage(_ newStage: Stage) {
        cancelPending()
        stage = newStage
        outcomes = []
        tries = 0
        totalTries = 0
        tip = nil
        failedStrokes = []
        problemStrokes = []
        justPassed = nil
        celebrationStart = nil
        stageStart = Date()
        token = UUID()
        ink.clear()
        guard !glyph.isEmpty else { items = []; return }
        if newStage == .tracing {
            let plan = (try? CoreBridge.plan(glyph, style: style))
            items = plan.map { p in [Guide.learn, .learn, .learn, .faint, .faint, .faint].map { Item(plan: p, guide: $0) } } ?? []
            startDemo()
        } else {
            let group = String(repeating: glyph, count: 3)
            let plan = (try? CoreBridge.plan(group, style: style))
            items = plan.map { p in [Guide.faint, .faint, .faint, .lines, .lines, .lines].map { Item(plan: p, guide: $0) } } ?? []
        }
    }

    private func continueFromStats() {
        if stage == .tracingStats {
            beginStage(.training)
        } else {
            finishLetter()
        }
    }

    private func finishStage() {
        cancelPending()
        stageSeconds = Date().timeIntervalSince(stageStart)
        let start = Date()
        celebrationStart = start
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stage = stage == .tracing ? .tracingStats : .trainingStats
    }

    /// The first step of the next letter (or nil at the end of the journey).
    private func nextLetterPosition() -> LessonPosition? {
        guard let j = journey, let c = chapter, let last = c.steps.last else { return nil }
        var end = position
        end.step = last
        return journeys.next(after: end, in: j)
    }

    private func finishLetter() {
        guard let j = journey, let c = chapter else { return }
        for step in c.scoredSteps {
            var p = position
            p.step = step
            journeys.markComplete(p, glyph: glyph)
        }
        if review {
            leave()
            return
        }
        guard let next = nextLetterPosition() else {
            replaceRoute(with: .recap(j.id))
            return
        }
        journeys.setPosition(next)
        if let nextChapter = j.chapter(next.chapterID), nextChapter.isCheckpoint {
            journeys.lockCheckpointPicks(nextChapter, in: j)
            replaceRoute(with: .lesson(next, review: false))
            return
        }
        position = next
        beginStage(.tracing)
    }

    private func leave() {
        cancelPending()
        if !path.isEmpty { path.removeLast() }
    }

    private func replaceRoute(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    // MARK: - Demo

    private func startDemo() {
        guard let template else { return }
        let start = Date()
        demoStart = start
        DispatchQueue.main.asyncAfter(deadline: .now() + StrokeDemoView.duration(for: template) + 0.6) {
            if demoStart == start { demoStart = nil }
        }
    }

    private func replayDemo() {
        cancelPending()
        ink.clear()
        startDemo()
    }

    // MARK: - Automatic checking

    private var expectsMoreStrokes: Bool {
        guard let t = template else { return false }
        let fewest = ([t.strokes.count] + (t.alternates ?? []).map(\.count)).min() ?? 1
        return ink.strokeCount < fewest
    }

    private func inkChanged() {
        cancelPending()
        guard stage == .tracing || stage == .training, ink.strokeCount > 0, !ink.isDrawing else { return }
        schedule()
    }

    private func drawingChanged(_ drawing: Bool) {
        guard stage == .tracing || stage == .training else { return }
        if drawing {
            cancelPending()
            demoStart = nil
            tip = nil
            failedStrokes = []
            problemStrokes = []
        } else if ink.strokeCount > 0 {
            schedule()
        }
    }

    private func schedule() {
        cancelPending()
        let delay = isTraining ? LetterSessionView.groupPause
            : (expectsMoreStrokes ? LetterSessionView.longPause : LetterSessionView.pause)
        let revision = ink.revision
        let snapshot = token
        checking = true
        let work = DispatchWorkItem { check(revision: revision, token: snapshot) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
        checking = false
    }

    private func check(revision: Int, token snapshot: UUID) {
        guard snapshot == token, revision == ink.revision, !ink.isDrawing, ink.strokeCount > 0,
              current < items.count, sheetSize != .zero else { return }
        pending = nil
        checking = false
        let item = items[current]
        let layout = cell(current, in: sheetSize).layout
        let strokes = ink.capturedStrokes(in: layout)
        let finger = ink.lastInkUsedFinger

        var score = 0
        var advice: String?
        var problems = Set<Int>()
        if isTraining {
            // Wait until the whole group has been written.
            let xs = strokes.flatMap { $0.points.map(\.x) }
            if let minX = xs.min(), let maxX = xs.max(), CGFloat(maxX - minX) < item.plan.width * 0.6 {
                tip = "Keep going: write all three."
                return
            }
            let r = CoreBridge.scoreLine(strokes: strokes, plan: item.plan, traced: item.guide != .lines, finger: finger)
            score = r.overall
            advice = r.tip
        } else {
            guard let template, let json = library.json(for: template.id),
                  let r = try? CoreBridge.score(strokes: strokes, templateID: template.id, templateJSON: json,
                                                mode: item.guide == .learn ? .learn : .practice, finger: finger)
            else { return }
            score = r.overall
            advice = r.tip
            problems = r.problemStrokes
        }

        tries += 1
        totalTries += 1
        if score >= LetterSessionView.passScore || tries >= LetterSessionView.maxTries {
            pass(strokes: strokes, score: score, item: item)
        } else {
            tip = advice ?? "Nearly. Try that one again."
            failedStrokes = strokes
            problemStrokes = problems
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            let resetToken = token
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if resetToken == token, !ink.isDrawing { ink.clear() }
            }
        }
    }

    private func pass(strokes: [CapturedStroke], score: Int, item: Item) {
        let index = current
        outcomes.append(Outcome(strokes: strokes, score: score))
        tries = 0
        tip = nil
        failedStrokes = []
        problemStrokes = []
        token = UUID()
        ink.clear()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        justPassed = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if justPassed == index { justPassed = nil } }

        // Progress: tracing counts as Learn, the traced row as Practice, the
        // written row as Test (and feeds the journey recap).
        let mode: WritingMode = !isTraining ? .learn : (item.guide == .lines ? .test : .practice)
        progress.record(score: score, mode: mode, templateID: templateID)
        if isTraining, item.guide == .lines, let j = journey {
            journeys.noteMemoryAttempt(journey: j, glyph: glyph, strokes: strokes, score: score, issue: nil)
        }

        if outcomes.count >= items.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { finishStage() }
        }
    }

    /// The canvas was resized: clear the ink for the current exercise only.
    private func restartItem() {
        cancelPending()
        tip = nil
        failedStrokes = []
        token = UUID()
        ink.clear()
    }
}

/// Ruled writing lines inside one cell of the sheet.
private struct CellRules: View {
    let frame: CGRect
    let layout: GuideLayout

    var body: some View {
        Canvas { context, _ in
            let rules: [(CGFloat, Double, CGFloat, [CGFloat])] = [
                (0.0, 0.35, 1, []), (0.5, 0.45, 1, [6, 5]), (1.0, 0.8, 1.5, []), (1.5, 0.35, 1, []),
            ]
            for (units, opacity, width, dash) in rules {
                let y = layout.y(units)
                guard y >= frame.minY - 2, y <= frame.maxY + 2 else { continue }
                var path = Path()
                path.move(to: CGPoint(x: frame.minX + 8, y: y))
                path.addLine(to: CGPoint(x: frame.maxX - 8, y: y))
                context.stroke(path, with: .color(Color.rule.opacity(opacity)),
                               style: StrokeStyle(lineWidth: width, dash: dash))
            }
        }
    }
}

/// Recorded strokes (in line units) drawn back on the page.
struct InkReplay: View {
    let strokes: [CapturedStroke]
    let layout: GuideLayout
    var color: Color = .ink

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                let pts = stroke.points.map { layout.toScreen(CGPoint(x: $0.x, y: $0.y)) }
                guard let first = pts.first else { continue }
                var path = Path()
                if pts.count == 1 {
                    path.addEllipse(in: CGRect(x: first.x - 2.5, y: first.y - 2.5, width: 5, height: 5))
                    context.fill(path, with: .color(color))
                } else {
                    path.addLines(pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
