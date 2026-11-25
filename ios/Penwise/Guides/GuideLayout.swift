import CoreGraphics

/// Maps between screen points and "line units" used by the scoring engine.
///
/// Line units: y = 0 ascender line, 0.5 x-height line, 1.0 baseline,
/// 1.5 descender line. One unit = the distance from ascender to baseline.
struct GuideLayout: Equatable {
    /// Screen position of line-unit (0, 0): left edge of the letter, on the ascender line.
    var origin: CGPoint
    /// Screen points per line unit.
    var unit: CGFloat

    func toUnits(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - origin.x) / unit, y: (p.y - origin.y) / unit)
    }

    func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * unit, y: origin.y + p.y * unit)
    }

    /// Screen y of a horizontal guide line given in line units.
    func y(_ lineUnits: CGFloat) -> CGFloat {
        origin.y + lineUnits * unit
    }

    /// Centres a letter of the given width (in line units) in the available space.
    static func fit(in size: CGSize, letterWidth: CGFloat) -> GuideLayout {
        guard size.width > 0, size.height > 0 else {
            return GuideLayout(origin: .zero, unit: 1)
        }
        let byHeight = size.height / 1.9
        let byWidth = size.width / max(letterWidth + 0.8, 1.4)
        let unit = max(80, min(byHeight, byWidth, 340))
        let origin = CGPoint(
            x: (size.width - letterWidth * unit) / 2,
            y: (size.height - 1.5 * unit) / 2
        )
        return GuideLayout(origin: origin, unit: unit)
    }
}
