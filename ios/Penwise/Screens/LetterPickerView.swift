import SwiftUI

/// All letters for one mode, with stars and best scores.
struct LetterPickerView: View {
    let mode: WritingMode

    @ObservedObject private var progress = ProgressStore.shared
    private let library = TemplateLibrary.shared

    /// The first letter not yet passed in this mode.
    private var upNext: LetterTemplate? {
        library.templates.first { (progress.best(mode, $0.id) ?? 0) < ProgressStore.passMark }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(mode.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(mode.rawValue) mode")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text(mode.subtitle)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if let next = upNext {
                    NavigationLink(value: Route.write(mode, next.id)) {
                        HStack(spacing: 16) {
                            Text(next.glyph)
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .frame(width: 64, height: 64)
                                .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Up next")
                                    .font(.subheadline.weight(.semibold))
                                    .opacity(0.85)
                                Text(mode.callToAction + " with \u{201C}\(next.glyph)\u{201D}")
                                    .font(.title3.weight(.bold))
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 36))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(mode.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    Label("Every letter passed in \(mode.rawValue) mode. Brilliant!", systemImage: "trophy.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(mode.color)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(library.templates) { template in
                        NavigationLink(value: Route.write(mode, template.id)) {
                            LetterTile(glyph: template.glyph, best: progress.best(mode, template.id), color: mode.color)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
