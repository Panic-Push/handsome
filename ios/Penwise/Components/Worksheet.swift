import SwiftUI

/// A letter drawn from its template in solid ink, so print and cursive show
/// the exact shapes taught (a system font would not match).
struct LetterThumbnail: View {
    let template: LetterTemplate
    var lineWidth: CGFloat = 3.5
    var color: Color = .ink

    var body: some View {
        Canvas { context, size in
            // Fit the full writing zone (ascender to descender, 1.5 units) so
            // letters keep their relative sizes.
            let unit = min(size.height / 1.6, size.width / max(CGFloat(template.width) + 0.2, 0.6))
            let origin = CGPoint(
                x: (size.width - CGFloat(template.width) * unit) / 2,
                y: (size.height - 1.5 * unit) / 2
            )
            for stroke in template.strokes {
                let points = stroke.cgPoints.map { CGPoint(x: origin.x + $0.x * unit, y: origin.y + $0.y * unit) }
                guard let first = points.first else { continue }
                var path = Path()
                if PathMath.length(points) < unit * 0.05 {
                    path.addEllipse(in: CGRect(x: first.x - lineWidth, y: first.y - lineWidth, width: 2 * lineWidth, height: 2 * lineWidth))
                    context.fill(path, with: .color(color))
                } else {
                    path.addLines(points)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .accessibilityLabel(template.spokenName)
    }
}

/// A small worksheet showing how a mode looks: same letter and ruling,
/// with a start dot and arrow (Learn), a faint model (Practice) or blank
/// lines (Test).
struct WorksheetPreview: View {
    let template: LetterTemplate?
    let mode: WritingMode

    var body: some View {
        GeometryReader { geo in
            let layout = GuideLayout.fit(in: geo.size, letterWidth: CGFloat(template?.width ?? 0.5))
            ZStack(alignment: .topTrailing) {
                Color.paper
                RuledLinesView(layout: layout)
                if let template {
                    switch mode {
                    case .learn:
                        TemplateOverlay(template: template, layout: layout)
                    case .practice:
                        TemplateOverlay(template: template, layout: layout, showArrows: false, showDots: false,
                                        pathOpacity: 0.25, solidPath: true)
                    case .test:
                        HStack(spacing: 6) {
                            Text("Write")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            LetterThumbnail(template: template, lineWidth: 2)
                                .frame(width: 26, height: 30)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.paperCard, in: Capsule())
                        .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
                        .padding(10)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
        .allowsHitTesting(false)
    }
}

/// The previous try, drawn faint and dotted under the new one for comparison.
struct AttemptGhost: View {
    let strokes: [CapturedStroke]
    let layout: GuideLayout

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                let points = stroke.points.map { layout.toScreen(CGPoint(x: $0.x, y: $0.y)) }
                guard points.count > 1 else { continue }
                var path = Path()
                path.addLines(points)
                context.stroke(
                    path,
                    with: .color(Color.gray.opacity(0.5)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [1, 7])
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// The letter to write in Test mode, shown in the corner of the page.
struct TargetLetterCard: View {
    let template: LetterTemplate
    let hinted: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Write")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(template.spokenName)
                    .font(.workbook(.headline))
                    .foregroundStyle(Color.ink)
                if hinted {
                    Text("With hint")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                }
            }
            LetterThumbnail(template: template, lineWidth: 3)
                .frame(width: 48, height: 56)
        }
        .padding(12)
        .paperCard(radius: 16)
        .allowsHitTesting(false)
    }
}
