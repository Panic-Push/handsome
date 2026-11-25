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
                    proxy.scrollTo(store.position(in: journey).chapterID, anchor: .top)
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
                    .font(.system(size: 36, weight: .bold, design: .serif))
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

            ZStack(alignment: .leading) {
                // The ruled row and the line joining the tiles.
                VStack(spacing: 0) {
                    Rectangle().fill(Color.rule.opacity(0.35)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(Color.rule.opacity(0.7)).frame(height: 2)
                }
                .frame(height: 132)
                Rectangle()
                    .fill(Color.rule.opacity(0.5))
                    .frame(width: CGFloat(max(letters.count - 1, 0)) * 132, height: 2)
                    .padding(.leading, 56)

                HStack(spacing: 20) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, glyph in
                        let isCurrent = !finished && current.chapterID == chapter.id && current.letterIndex == index
                        let isDone = store.isComplete(glyph, chapter, in: journey)
                        tile(glyph: glyph, order: index + 1, isCurrent: isCurrent, isDone: isDone,
                             needsReview: isDone && store.needsReview(glyph, in: journey), in: journey) {
                            if isCurrent {
                                path.append(.lesson(current, review: false))
                            } else if isDone {
                                let start = LessonPosition(journeyID: journey.id, chapterID: chapter.id,
                                                           letterIndex: index, step: chapter.steps[0])
                                path.append(.lesson(start, review: true))
                            }
                        }
                    }
                }
            }
        }
        .padding(22)
        .paperCard(radius: 24)
    }

    private func tile(glyph: String, order: Int, isCurrent: Bool, isDone: Bool, needsReview: Bool,
                      in journey: Journey, action: @escaping () -> Void) -> some View {
        let template = library.template(id: journey.templateID(glyph))
        let accent = WritingMode.learn.color
        return Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.paperCard)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isCurrent ? accent : Color.cardBorder, lineWidth: isCurrent ? 3 : 1)
                    if let template {
                        LetterThumbnail(template: template, lineWidth: 3.5,
                                        color: isDone || isCurrent ? .ink : .ink.opacity(0.35))
                            .padding(10)
                    }
                }
                .frame(width: 112, height: 112)
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
        .disabled(!isCurrent && !isDone)
        .accessibilityLabel("\(glyph), \(isCurrent ? "up next" : isDone ? "complete" : "upcoming")")
    }

    private func chapterColor(_ number: Int) -> Color {
        [WritingMode.learn.color, WritingMode.practice.color, WritingMode.test.color][(number - 1) % 3]
    }
}
