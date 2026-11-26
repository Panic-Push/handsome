import SwiftUI

/// Colours, icons and words for each mode, shared by every screen.
extension WritingMode {
    /// Learn remains a scoring category for guided strokes and existing history.
    static let selectable: [WritingMode] = [.practice, .test]

    var color: Color {
        switch self {
        case .learn: return Color.courseViolet
        case .practice: return Color(red: 0.10, green: 0.43, blue: 0.42)
        case .test: return Color(red: 0.62, green: 0.29, blue: 0.14)
        }
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
