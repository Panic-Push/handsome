import SwiftUI
import UIKit

/// Workbook colours: indigo, soft paper and dark ink, with dark-mode versions.
extension Color {
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    static let courseViolet = dynamic(light: (0.34, 0.25, 0.69), dark: (0.65, 0.60, 0.98))
    static let courseApricot = dynamic(light: (1.0, 0.78, 0.64), dark: (0.34, 0.22, 0.17))
    static let courseMint = dynamic(light: (0.65, 0.89, 0.85), dark: (0.12, 0.29, 0.27))
    static let courseRose = dynamic(light: (0.95, 0.74, 0.80), dark: (0.33, 0.17, 0.22))

    /// Page background.
    static let paper = dynamic(light: (0.949, 0.951, 0.984), dark: (0.075, 0.078, 0.125))
    /// Cards and bars sitting on the page.
    static let paperCard = dynamic(light: (1, 1, 1), dark: (0.127, 0.133, 0.196))
    /// Main text and drawings.
    static let ink = dynamic(light: (0.119, 0.115, 0.200), dark: (0.949, 0.951, 0.984))
    /// Ruled lines.
    static let rule = dynamic(light: (0.62, 0.58, 0.52), dark: (0.50, 0.47, 0.43))
    /// Soft card borders.
    static let cardBorder = dynamic(light: (0.82, 0.82, 0.90), dark: (0.26, 0.245, 0.23))
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
