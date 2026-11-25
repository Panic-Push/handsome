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

    /// Places a letter of the given width (in line units) in the available space.
    /// `large` uses bigger writing lines. The letter sits a little away from the
    /// writing hand's side, leaving room for the palm.
    static func fit(in size: CGSize, letterWidth: CGFloat, large: Bool = false, leftHanded: Bool = false) -> GuideLayout {
        guard size.width > 0, size.height > 0 else {
            return GuideLayout(origin: .zero, unit: 1)
        }
        let byHeight = size.height / 1.75
        let byWidth = size.width / max(letterWidth + 0.8, 1.4)
        let cap: CGFloat = large ? 380 : 260
        let unit = max(60, min(byHeight, byWidth, cap))
        let letter = letterWidth * unit
        let centre = size.width * (leftHanded ? 0.58 : 0.42)
        let x = min(max(centre - letter / 2, 16), max(16, size.width - letter - 16))
        return GuideLayout(origin: CGPoint(x: x, y: (size.height - 1.5 * unit) / 2), unit: unit)
    }
}
