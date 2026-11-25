import SwiftUI

/// Colours, icons and words for each mode, shared by every screen.
extension WritingMode {
    var color: Color {
        switch self {
        case .learn: return Color(red: 0.16, green: 0.45, blue: 0.96)
        case .practice: return Color(red: 0.98, green: 0.55, blue: 0.12)
        case .test: return Color(red: 0.55, green: 0.32, blue: 0.92)
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
        case .learn: return "Watch each letter being written, then trace it with arrows and dots to guide you."
        case .practice: return "Write over a faint letter and build muscle memory for shape and stroke order."
        case .test: return "Write from memory on plain lines. Size, slant and baseline all count."
        }
    }

    var callToAction: String {
        switch self {
        case .learn: return "Start tracing"
        case .practice: return "Start practising"
        case .test: return "Take a test"
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
