import SwiftUI

/// A notebook page per chapter: letter tiles along a ruled row, joined by a
/// line. Opens at the current chapter. Completed letters stay tappable for review.
struct JourneyMapView: View {
    let journeyID: String
    @Binding var path: [Route]

    @State private var choice: LetterChoice?
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
                        if let style = LetterStyle(rawValue: journey.style) {
                            Menu {
                                ForEach(WritingMode.selectable) { mode in
                                    Button(mode.rawValue) { path.append(.sentences(style, mode, nil)) }
                                }
                            } label: {
                                Label("Write sentences", systemImage: "pencil.and.scribble")
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        HStack {
                            ForEach(WritingMode.selectable) { mode in
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
        .sheet(item: $choice) { picked in
            if let journey {
                ModeChoiceSheet(choice: picked, journey: journey) { route in
                    choice = nil
                    // Navigate once the card has started to close.
                    DispatchQueue.main.async { path.append(route) }
                }
                .presentationDetents([.height(picked.isCheckpoint ? 620 : 570), .large])
                .presentationBackground(Color.paper)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
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
                Text("\(journey.subtitle) · \(Set(journey.chapters.flatMap(\.letters)).count) letters")
                    .font(.workbook(.title3, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            WorkbookFox(pose: .dash).frame(width: 92, height: 72)
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
                    Text(chapter.isCheckpoint ? chapter.title : "Chapter \(number) of \(journey.chapters.filter { !$0.isCheckpoint }.count) · \(chapter.title)")
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
                    .stroke(Color.courseAccent.opacity(0.32), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [3, 12]))
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, glyph in
                        let isCurrent = !finished && current.chapterID == chapter.id && current.letterIndex == index
                        let isDone = store.isComplete(glyph, chapter, in: journey)
                        tile(glyph: glyph, order: index + 1, isCurrent: isCurrent, isDone: isDone,
                             needsReview: isDone && store.needsReview(glyph, in: journey), in: journey) {
                            let position = isCurrent ? current : LessonPosition(journeyID: journey.id, chapterID: chapter.id,
                                                                                letterIndex: index, step: chapter.steps[0])
                            choice = LetterChoice(position: position, glyph: glyph, chapterTitle: chapter.title,
                                                  isCheckpoint: chapter.isCheckpoint,
                                                  isSavedPlace: position == store.position(in: journey))
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
        let accent = Color.courseAccent
        return Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(isCurrent ? Color.courseAccent : Color.cardBorder).offset(y: 5)
                    Circle()
                        .fill(isCurrent ? Color.courseAccent : isDone ? Color.courseMint : Color.paperCard)
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

/// The letter tapped on the map, and where it sits in the course.
struct LetterChoice: Identifiable {
    let position: LessonPosition
    let glyph: String
    let chapterTitle: String
    let isCheckpoint: Bool
    let isSavedPlace: Bool

    var id: String { "\(position.chapterID)-\(position.letterIndex)" }
}

/// A card for choosing how to write the tapped letter. Each choice keeps
/// going from this letter through the rest of the course, one after another.
private struct ModeChoiceSheet: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let choice: LetterChoice
    let journey: Journey
    let open: (Route) -> Void

    private let library = TemplateLibrary.shared

    private var template: LetterTemplate? { library.template(id: journey.templateID(choice.glyph)) }

    /// Course letters from the tapped one to the end, in course order.
    private var remaining: [String] {
        let all = journey.chapters.filter { !$0.isCheckpoint }.flatMap(\.letters)
        guard let start = all.firstIndex(of: choice.glyph) else { return [choice.glyph] }
        return Array(all[start...])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    if let template {
                        LetterThumbnail(template: template, lineWidth: 4)
                            .frame(width: 72, height: 80)
                            .background(Color.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Write \(choice.glyph)")
                            .font(.workbook(.largeTitle, weight: .bold))
                            .foregroundStyle(Color.ink)
                        Text("\(choice.chapterTitle) · then on through the course, one letter after another")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    WorkbookFox(pose: .peek).frame(width: 72, height: 64)
                }

                let cards = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))
                cards {
                    ForEach(WritingMode.selectable) { mode in
                        Button { pick(mode) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                WorksheetPreview(template: template, mode: mode)
                                    .frame(height: 110)
                                HStack {
                                    Label(mode.rawValue, systemImage: mode.symbol)
                                    Spacer()
                                    Image(systemName: "chevron.right").accessibilityHidden(true)
                                }
                                    .font(.headline)
                                    .foregroundStyle(mode.color)
                                Text(mode.cardLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.paperCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(mode.color.opacity(0.35), lineWidth: 1.5))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHint(mode == .practice ? "Starts the guided lesson" : "Writes the letters in a row")
                    }
                }

                if choice.isCheckpoint {
                    Button { open(.lesson(choice.position, review: !choice.isSavedPlace)) } label: {
                        Label("Take the checkpoint", systemImage: "flag.checkered")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.courseAccent)
                }
                AdSlot(placement: .home)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .background(Color.paper)
    }

    private func pick(_ mode: WritingMode) {
        if mode == .practice && !choice.isCheckpoint {
            open(.lesson(choice.position, review: !choice.isSavedPlace))
        } else {
            let ids = remaining.map { journey.templateID($0) }
            open(.set(mode, "\(mode.rawValue) from \(choice.glyph)", ids, shuffled: false))
        }
    }
}
