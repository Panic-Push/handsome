import SwiftUI

/// A notebook page per chapter: letter tiles along a ruled row, joined by a
/// line. Opens at the current chapter. Completed letters stay tappable for review.
struct JourneyMapView: View {
    let journeyID: String
    @Binding var path: [Route]

    @ObservedObject private var store = JourneyStore.shared
    @ObservedObject private var progress = ProgressStore.shared
    private let library = TemplateLibrary.shared

    private var journey: Journey? { JourneyLibrary.shared.journey(id: journeyID) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let journey {
                    VStack(alignment: .leading, spacing: 28) {
                        header(journey)
                        HStack {
                            ForEach(WritingMode.allCases) { mode in
                                Button {
                                    path.append(.letters(mode))
                                } label: {
                                    Label(mode.rawValue, systemImage: mode.symbol)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        ForEach(Array(journey.chapters.enumerated()), id: \.element.id) { index, chapter in
                            chapterSection(chapter, number: index + 1, in: journey)
                                .id(chapter.id)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
                } else {
                    Text("This journey could not be loaded.")
                        .padding(40)
                }
            }
            .background(Color.paper)
            .onAppear {
                if let journey {
                    let p = store.position(in: journey)
                    proxy.scrollTo("\(p.chapterID)-\(p.letterIndex)", anchor: .center)
                }
            }
        }
        .navigationTitle(journey?.title ?? "Journey")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ journey: Journey) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(journey.title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text(journey.subtitle)
                    .font(.workbook(.title3, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isFinished(journey) {
                Button {
                    path.append(.recap(journey.id))
                } label: {
                    Label("See recap", systemImage: "rosette")
                }
                .buttonStyle(.borderedProminent)
                .tint(WritingMode.learn.color)
            }
        }
    }

    private func chapterSection(_ chapter: Journey.Chapter, number: Int, in journey: Journey) -> some View {
        let letters = store.letters(chapter, in: journey)
        let done = store.completedCount(chapter, in: journey)
        let current = store.position(in: journey)
        let finished = store.isFinished(journey)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Text(chapter.isCheckpoint ? "✓" : "\(number)")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(chapterColor(number), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .font(.workbook(.title2))
                        .foregroundStyle(Color.ink)
                    Text(chapter.goal)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Label("\(done) of \(letters.count) complete",
                      systemImage: done == letters.count ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done == letters.count ? Color.green : Color.secondary)
            }

            GeometryReader { bounds in
                let middle = bounds.size.width / 2
                let swing = min(bounds.size.width * 0.18, 92)
                let row: CGFloat = 126
                let centers = letters.indices.map { index in
                    CGPoint(x: middle + (index.isMultiple(of: 2) ? -swing : swing),
                            y: CGFloat(index) * row + row / 2)
                }
                ZStack(alignment: .topLeading) {
                    Path { trail in
                        guard let first = centers.first else { return }
                        trail.move(to: first)
                        for (from, to) in zip(centers, centers.dropFirst()) {
                            let midY = (from.y + to.y) / 2
                            trail.addCurve(to: to, control1: CGPoint(x: from.x, y: midY),
                                           control2: CGPoint(x: to.x, y: midY))
                        }
                    }
                    .stroke(Color.courseViolet.opacity(0.32), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, glyph in
                        let isCurrent = !finished && current.chapterID == chapter.id && current.letterIndex == index
                        let isDone = store.isComplete(glyph, chapter, in: journey)
                        tile(glyph: glyph, order: index + 1, isCurrent: isCurrent, isDone: isDone,
                             needsReview: isDone && store.needsReview(glyph, in: journey), in: journey) {
                            if isCurrent {
                                path.append(.lesson(current, review: false))
                            } else {
                                let start = LessonPosition(journeyID: journey.id, chapterID: chapter.id,
                                                           letterIndex: index, step: chapter.steps[0])
                                path.append(.lesson(start, review: true))
                            }
                        }
                        .id("\(chapter.id)-\(index)")
                        .position(centers[index])
                    }
                }
            }
            .frame(height: CGFloat(letters.count) * 126)
        }
        .padding(22)
        .paperCard(radius: 24)
    }

    private func tile(glyph: String, order: Int, isCurrent: Bool, isDone: Bool, needsReview: Bool,
                      in journey: Journey, action: @escaping () -> Void) -> some View {
        let template = library.template(id: journey.templateID(glyph))
        let accent = Color.courseViolet
        return Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? Color.courseViolet : isDone ? Color.courseMint : Color.paperCard)
                    Circle()
                        .stroke(isCurrent ? accent : Color.cardBorder, lineWidth: isCurrent ? 3 : 1)
                    if let template {
                        LetterThumbnail(template: template, lineWidth: 3.5,
                                        color: isCurrent ? .white : isDone ? .ink : .ink.opacity(0.55))
                            .padding(10)
                    }
                }
                .frame(width: 80, height: 80)
                .overlay(alignment: .topTrailing) {
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.green)
                            .background(Circle().fill(Color.paperCard))
                            .offset(x: 6, y: -6)
                    }
                }
                Group {
                    if isCurrent {
                        Text("Up next").foregroundStyle(accent)
                    } else if needsReview {
                        Text("Review").foregroundStyle(Color.orange)
                    } else if isDone {
                        Text("Done").foregroundStyle(Color.green)
                    } else {
                        Text("\(order)").foregroundStyle(.secondary)
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(glyph), \(isCurrent ? "up next" : isDone ? "complete" : "upcoming")")
    }

    private func chapterColor(_ number: Int) -> Color {
        [WritingMode.learn.color, WritingMode.practice.color, WritingMode.test.color][(number - 1) % 3]
    }
}
