import CoreGraphics
import Foundation

/// Runs the starting assessment: six letters, a word and a sentence, all
/// written from memory, then builds the report and the plan.
///
/// Front end: show `current.prompt`, draw guides with `layout(in:)`, convert
/// the ink with `InkModel.capturedStrokes(in: layout(in: size))`, then call
/// `submit(...)`. When `report` is set, the assessment is finished (and the
/// report is already saved in `PlanStore`).
final class AssessmentSession: ObservableObject {
    let style: LetterStyle
    let tasks: [AssessmentTaskInfo]

    @Published private(set) var index = 0
    /// Score of the task just submitted (for a quiet tick, not a big result).
    @Published private(set) var lastScore: Int?
    @Published private(set) var report: HandwritingReport?
    @Published private(set) var errorText: String?

    private let recorder = AssessmentRecorder()

    init(style: LetterStyle) {
        self.style = style
        self.tasks = LearningBridge.assessmentTasks
    }

    var current: AssessmentTaskInfo? { tasks.indices.contains(index) ? tasks[index] : nil }
    var isFinished: Bool { report != nil }
    /// 0...1
    var progress: Double { tasks.isEmpty ? 1 : Double(index) / Double(tasks.count) }

    /// The plan of the current word or sentence (nil for single letters).
    var currentPlan: LinePlan? {
        guard let task = current, task.isLine else { return nil }
        return try? CoreBridge.plan(task.text, style: style)
    }

    /// Writing lines for the current task in a canvas of `size`: a single
    /// letter gets one large letter box, a word or sentence one long line.
    func layout(in size: CGSize) -> GuideLayout {
        guard let task = current else { return GuideLayout.fit(in: size, letterWidth: 0.6) }
        if task.isLine {
            let width = (currentPlan?.width ?? CGFloat(task.text.count) * 0.5) + 0.6
            let unit = max(30, min(size.height / 1.8, size.width / width))
            return GuideLayout(origin: CGPoint(x: unit * 0.3, y: (size.height - 1.5 * unit) / 2), unit: unit)
        }
        return GuideLayout.fit(in: size, letterWidth: 0.6)
    }

    /// Scores the current task and moves on. `seconds` is the time from first
    /// touch to last lift (negative if unknown); it measures writing speed.
    func submit(strokes: [CapturedStroke], seconds: Double, finger: Bool) {
        guard let task = current, !strokes.isEmpty else { return }
        errorText = nil
        if task.isLine {
            guard let plan = currentPlan else { skip(); return }
            lastScore = recorder.addLine(task.text, plan: plan, strokes: strokes, seconds: seconds, finger: finger)
        } else {
            do {
                lastScore = try recorder.addLetter(task.text, strokes: strokes, style: style, finger: finger)
            } catch {
                errorText = "That letter could not be checked."
            }
        }
        advance()
    }

    /// Skips the current task (it is left out of the report).
    func skip() {
        lastScore = nil
        advance()
    }

    private func advance() {
        index += 1
        if index >= tasks.count {
            let r = recorder.report(style: style)
            PlanStore.shared.save(report: r)
            report = r
        }
    }
}
