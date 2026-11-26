import SwiftUI

/// Colours, icons and words for each mode, shared by every screen.
extension WritingMode {
    /// Learn remains a scoring category for guided strokes and existing history.
    static let selectable: [WritingMode] = [.practice, .test]

    var color: Color {
        .courseViolet
    }

    var symbol: String {
        switch self {
        case .learn: return "pencil.and.outline"
        case .practice: return "pencil.tip.crop.circle"
        case .test: return "checkmark.seal"
        }
    }

    var subtitle: String {
        switch self {
        case .learn: return "Watch the letter, then trace it from the start dot."
        case .practice: return "Trace the letter, follow a lighter guide, then write from memory."
        case .test: return "Write from memory on blank lines."
        }
    }

    /// Short label under each Home card.
    var cardLabel: String {
        switch self {
        case .learn: return "Watch and trace"
        case .practice: return "Write with a guide"
        case .test: return "Write from memory"
        }
    }

    var callToAction: String {
        switch self {
        case .learn: return "Continue to Learn"
        case .practice: return "Continue to Practice"
        case .test: return "Continue to Test"
        }
    }
}

/// Buttons that shrink slightly while pressed.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
