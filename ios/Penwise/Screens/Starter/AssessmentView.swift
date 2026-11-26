import SwiftUI

/// STARTER SCREEN (to be redesigned): the starting assessment.
/// Uses `AssessmentSession`; see docs/FRONTEND_HANDOFF.md.
struct AssessmentView: View {
    @Binding var path: [Route]
    @StateObject private var session: AssessmentSession
    @StateObject private var ink = InkModel()
    @State private var size: CGSize = .zero
    @State private var firstTouch: Date?
    @State private var lastLift: Date?

    init(style: LetterStyle, path: Binding<[Route]>) {
        _path = path
        _session = StateObject(wrappedValue: AssessmentSession(style: style))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProgressView(value: session.progress)
            if let report = session.report {
                ReportContent(report: report)
                Button("See my plan") { replaceWithPlan() }
                    .buttonStyle(.borderedProminent)
            } else if let task = session.current {
                Text("Task \(session.index + 1) of \(session.tasks.count)").font(.headline).foregroundStyle(.secondary)
                Text(task.prompt).font(.workbook(.title2))
                GeometryReader { geo in
                    ZStack {
                        RuledLinesView(layout: session.layout(in: geo.size))
                        InkCanvas(model: ink)
                    }
                    .onAppear { size = geo.size }
                    .onChange(of: geo.size) { _, s in size = s; ink.clear() }
                }
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 18))
                HStack {
                    Button("Done") { submit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(ink.strokeCount == 0 || ink.isDrawing)
                    Button("Clear") { ink.clear(); firstTouch = nil }
                    Spacer()
                    Button("Skip") { ink.clear(); firstTouch = nil; session.skip() }
                }
            }
        }
        .padding(28)
        .background(Color.paperCard)
        .navigationTitle("Handwriting check")
        .onChange(of: ink.isDrawing) { _, drawing in
            if drawing && firstTouch == nil { firstTouch = Date() }
            if !drawing { lastLift = Date() }
        }
    }

    private func submit() {
        let seconds = firstTouch.flatMap { start in lastLift.map { $0.timeIntervalSince(start) } } ?? -1
        session.submit(strokes: ink.capturedStrokes(in: session.layout(in: size)), seconds: seconds,
                       finger: ink.lastInkUsedFinger)
        ink.clear()
        firstTouch = nil
        lastLift = nil
    }

    private func replaceWithPlan() {
        if !path.isEmpty { path.removeLast() }
        path.append(.plan)
    }
}

/// STARTER: the report body, shared by the assessment and the report screen.
struct ReportContent: View {
    let report: HandwritingReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ScoreRing(score: report.overall)
                Text(report.summary).font(.workbook(.title3))
            }
            if !report.focusTitles.isEmpty {
                Text("Work on: \(report.focusTitles.joined(separator: ", "))").font(.headline)
            }
            ForEach(report.skills) { skill in
                HStack {
                    Text(skill.title).frame(width: 170, alignment: .leading)
                    ProgressView(value: Double(skill.score), total: 100).tint(scoreColor(skill.score))
                    Text("\(skill.score)").monospacedDigit().frame(width: 36)
                }
            }
            if !report.weakLetters.isEmpty {
                Text("Letters to practise: \(report.weakLetters.joined(separator: " "))")
            }
            if let lpm = report.lettersPerMinute {
                Text("Speed: \(lpm) letters a minute").foregroundStyle(.secondary)
            }
        }
    }
}
