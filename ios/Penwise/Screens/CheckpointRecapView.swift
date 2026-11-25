import SwiftUI

/// After the checkpoint: the letters practised, one suggestion, and the first
/// and latest attempt of each letter side by side at the same scale.
struct CheckpointRecapView: View {
    let journeyID: String
    @Binding var path: [Route]

    @ObservedObject private var store = JourneyStore.shared
    @ObservedObject private var progress = ProgressStore.shared

    private var journey: Journey? { JourneyLibrary.shared.journey(id: journeyID) }

    var body: some View {
        ScrollView {
            if let journey {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Checkpoint complete", systemImage: "rosette")
                            .font(.headline)
                            .foregroundStyle(Color.green)
                        Text(journey.title)
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(Color.ink)
                    }

                    if let suggestion = store.suggestion(in: journey) {
                        HStack(spacing: 16) {
                            Image(systemName: "lightbulb.fill")
                                .font(.title)
                                .foregroundStyle(WritingMode.practice.color)
                            Text(suggestion.text)
                                .font(.workbook(.title2))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Button("Revisit \(suggestion.glyph)") { revisit(suggestion.glyph, in: journey) }
                                .buttonStyle(.borderedProminent)
                                .tint(WritingMode.practice.color)
                                .controlSize(.large)
                        }
                        .padding(20)
                        .paperCard(radius: 20)
                    }

                    Text("First try and latest, from memory")
                        .font(.workbook(.title3))
                        .foregroundStyle(Color.ink)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(practised(journey), id: \.self) { glyph in
                            letterRow(glyph, in: journey)
                        }
                    }

                    Button {
                        path.removeAll()
                    } label: {
                        Text("Back to Home").frame(minWidth: 220)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(32)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.paper)
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Every journey letter that has memory attempts, in course order.
    private func practised(_ journey: Journey) -> [String] {
        var seen = Set<String>()
        return journey.chapters.filter { !$0.isCheckpoint }.flatMap(\.letters)
            .filter { seen.insert($0).inserted && store.samples($0, in: journey) != nil }
    }

    private func letterRow(_ glyph: String, in journey: Journey) -> some View {
        let samples = store.samples(glyph, in: journey)
        let best = progress.best(.test, journey.templateID(glyph))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(glyph)
                    .font(.workbook(.title2))
                    .foregroundStyle(Color.ink)
                StarsView(count: ProgressStore.stars(for: best), size: 14)
                Spacer()
                if store.needsReview(glyph, in: journey) {
                    Text("Review")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                }
                Text(best.map { "Best \($0)" } ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let samples {
                HStack(spacing: 12) {
                    labelled("First", AttemptThumbnail(strokes: samples.first))
                    labelled("Latest", AttemptThumbnail(strokes: samples.latest))
                }
            }
        }
        .padding(16)
        .paperCard(radius: 18)
    }

    private func labelled(_ title: String, _ thumbnail: AttemptThumbnail) -> some View {
        VStack(spacing: 4) {
            thumbnail.frame(height: 110)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Opens the letter from its first step as a review, keeping the journey place.
    private func revisit(_ glyph: String, in journey: Journey) {
        guard let chapter = journey.chapters.first(where: { !$0.isCheckpoint && $0.letters.contains(glyph) }),
              let index = chapter.letters.firstIndex(of: glyph) else { return }
        let start = LessonPosition(journeyID: journey.id, chapterID: chapter.id, letterIndex: index, step: chapter.steps[0])
        path.append(.lesson(start, review: true))
    }
}

/// A recorded attempt drawn on its ruling. Every thumbnail uses the same
/// scale (set by its height), so first and latest can be compared directly.
struct AttemptThumbnail: View {
    let strokes: [CapturedStroke]

    var body: some View {
        Canvas { context, size in
            let unit = size.height / 1.6
            let top = (size.height - 1.5 * unit) / 2
            for line in [CGFloat(0.5), 1.0] {
                var rule = Path()
                rule.move(to: CGPoint(x: 0, y: top + line * unit))
                rule.addLine(to: CGPoint(x: size.width, y: top + line * unit))
                context.stroke(rule, with: .color(Color.rule.opacity(line == 1.0 ? 0.8 : 0.4)),
                               style: StrokeStyle(lineWidth: 1, dash: line == 1.0 ? [] : [4, 3]))
            }
            let xs = strokes.flatMap { $0.points.map(\.x) }
            guard let minX = xs.min(), let maxX = xs.max() else { return }
            let offset = (size.width - CGFloat(maxX - minX) * unit) / 2 - CGFloat(minX) * unit
            for stroke in strokes {
                let points = stroke.points.map { CGPoint(x: offset + CGFloat($0.x) * unit, y: top + CGFloat($0.y) * unit) }
                guard points.count > 1 else { continue }
                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(Color.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
