import SwiftUI

/// Colours, icons and words for each mode, shared by every screen.
extension WritingMode {
    var color: Color {
        switch self {
        case .learn: return Color(red: 0.18, green: 0.38, blue: 0.72)
        case .practice: return Color(red: 0.80, green: 0.46, blue: 0.12)
        case .test: return Color(red: 0.48, green: 0.28, blue: 0.62)
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
        case .practice: return "Write over a faint model, then with less guide."
        case .test: return "Write from memory on blank lines."
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
