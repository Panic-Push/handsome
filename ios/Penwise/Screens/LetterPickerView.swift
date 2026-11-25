import SwiftUI

/// All letters for one mode in the chosen style, with stars and best scores.
struct LetterPickerView: View {
    let mode: WritingMode

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    private let library = TemplateLibrary.shared

    private var letters: [LetterTemplate] { library.templates(style: settings.style) }

    /// The first letter not yet passed in this mode.
    private var upNext: LetterTemplate? {
        letters.first { (progress.best(mode, $0.id) ?? 0) < ProgressStore.passMark }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(mode.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(Color.ink)
                        Text(mode.subtitle)
                            .font(.workbook(.title3, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Letter style", selection: $settings.style) {
                        ForEach(LetterStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if let next = upNext {
                    NavigationLink(value: Route.write(mode, next.id)) {
                        HStack(spacing: 16) {
                            LetterThumbnail(template: next, lineWidth: 3.5, color: .white)
                                .frame(width: 64, height: 68)
                                .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Up next")
                                    .font(.subheadline.weight(.semibold))
                                    .opacity(0.85)
                                Text("\(mode.rawValue) \(next.spokenName)")
                                    .font(.workbook(.title2))
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
                } else if !letters.isEmpty {
                    Label("Every letter passed in \(mode.rawValue). Brilliant!", systemImage: "trophy.fill")
                        .font(.workbook(.title3))
                        .foregroundStyle(mode.color)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(letters) { template in
                        NavigationLink(value: Route.write(mode, template.id)) {
                            LetterTile(template: template, best: progress.best(mode, template.id), color: mode.color)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(32)
        }
        .background(Color.paper)
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
