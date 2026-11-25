import SwiftUI
import UIKit

/// Workbook colours: cream paper and dark ink, with dark-mode versions.
extension Color {
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    static let courseViolet = Color(red: 0.42, green: 0.19, blue: 0.66)
    static let courseApricot = dynamic(light: (1.0, 0.78, 0.64), dark: (0.34, 0.22, 0.17))
    static let courseMint = dynamic(light: (0.65, 0.89, 0.85), dark: (0.12, 0.29, 0.27))

    /// Page background.
    static let paper = dynamic(light: (0.980, 0.965, 0.930), dark: (0.110, 0.102, 0.094))
    /// Cards and bars sitting on the page.
    static let paperCard = dynamic(light: (1.0, 0.992, 0.968), dark: (0.160, 0.150, 0.138))
    /// Main text and drawings.
    static let ink = dynamic(light: (0.165, 0.149, 0.129), dark: (0.930, 0.905, 0.860))
    /// Ruled lines.
    static let rule = dynamic(light: (0.62, 0.58, 0.52), dark: (0.50, 0.47, 0.43))
    /// Soft card borders.
    static let cardBorder = dynamic(light: (0.88, 0.85, 0.80), dark: (0.26, 0.245, 0.23))
}

extension Font {
    /// Workbook headings.
    static func workbook(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded).weight(weight)
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
