import SwiftUI
import UIKit
import Lottie

/// Workbook colours: forest green, white paper and dark ink, with dark-mode versions.
extension Color {
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    static let courseFill = Color(red: 0.075, green: 0.40, blue: 0.25)
    static let courseAccent = dynamic(light: (0.075, 0.40, 0.25), dark: (0.48, 0.85, 0.62))
    static let courseApricot = dynamic(light: (1.0, 0.78, 0.64), dark: (0.34, 0.22, 0.17))
    static let courseMint = dynamic(light: (0.65, 0.89, 0.85), dark: (0.12, 0.29, 0.27))
    static let courseRose = dynamic(light: (0.95, 0.74, 0.80), dark: (0.33, 0.17, 0.22))

    /// Page background.
    static let paper = dynamic(light: (1, 1, 1), dark: (0.059, 0.086, 0.079))
    /// Cards and bars sitting on the page.
    static let paperCard = dynamic(light: (1, 1, 1), dark: (0.10, 0.14, 0.12))
    /// Main text and drawings.
    static let ink = dynamic(light: (0.10, 0.16, 0.13), dark: (0.949, 0.951, 0.984))
    /// Ruled lines.
    static let rule = dynamic(light: (0.62, 0.58, 0.52), dark: (0.50, 0.47, 0.43))
    /// Soft card borders.
    static let cardBorder = dynamic(light: (0.82, 0.87, 0.83), dark: (0.25, 0.31, 0.27))
}

extension Font {
    /// Workbook headings.
    static func workbook(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        let points: CGFloat
        switch style {
        case .largeTitle: points = 34
        case .title: points = 28
        case .title2: points = 22
        case .title3: points = 20
        case .caption, .caption2: points = 13
        default: points = 17
        }
        return .custom(weight == .regular ? "ChalkboardSE-Regular" : "ChalkboardSE-Bold",
                       size: points, relativeTo: style)
    }
}

/// A soft paper card.
struct PaperCard: ViewModifier {
    var radius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(Color.paperCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
    }
}

extension View {
    func paperCard(radius: CGFloat = 22) -> some View {
        modifier(PaperCard(radius: radius))
    }
}


enum FoxPose: String {
    case hello, idle, happy, watching, thinking, encourage, celebrate, oops, tap, dizzy, sneeze, sleepy
    case pencilBonk = "pencil_bonk"
    case splash = "splash_hi"
    case dash = "transition_dash"
    case peek = "transition_peek"
}

/// The mascot is decorative; instructions, scores and controls stay native.
struct WorkbookFox: View {
    let pose: FoxPose
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let animation = LottieView(animation: .asset("fox_" + pose.rawValue)).resizable()
        Group {
            if reduceMotion {
                animation.paused(at: .progress(0.35))
            } else {
                animation.playing()
            }
        }
        .id(pose)
        .aspectRatio(contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A raised action that settles into its base on touch.
struct LessonActionStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let depth: CGFloat = configuration.isPressed ? 1 : 4
        configuration.label
            .font(.headline)
            .frame(minHeight: 48)
            .padding(.horizontal, 18)
            .foregroundStyle(.white)
            .background(Color.courseFill, in: shape)
            .background(shape.fill(Color(red: 0.04, green: 0.26, blue: 0.15)).offset(y: depth))
            .offset(y: reduceMotion ? 0 : 4 - depth)
            .padding(.bottom, 4)
    }
}
