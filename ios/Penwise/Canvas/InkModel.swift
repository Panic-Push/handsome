import PencilKit
import SwiftUI

/// One captured pen sample in line units (matches the shared core's InkPoint).
struct CapturedPoint: Codable {
    var x: Double
    var y: Double
    /// Seconds since the stroke began.
    var t: Double
    /// Pressure 0...1, or -1 when unknown (finger).
    var force: Double
}

struct CapturedStroke: Codable {
    var points: [CapturedPoint]
}

struct InkStats {
    var strokes = 0
    var points = 0
    var averagePressure: Double?
    var usedFinger = false
    var seconds: Double = 0
}

/// Holds the drawing and provides undo, redo and clear.
final class InkModel: ObservableObject {
    /// When true, only Apple Pencil draws (palm and finger touches are ignored).
    @Published var pencilOnly = true
    @Published private(set) var strokeCount = 0
    @Published private(set) var revision = 0

    weak var canvas: PKCanvasView?

    private var redoStack: [PKStroke] = []
    private var isApplying = false

    var drawing: PKDrawing { canvas?.drawing ?? PKDrawing() }
    var canRedo: Bool { !redoStack.isEmpty }

    func drawingDidChange(_ drawing: PKDrawing) {
        if !isApplying && drawing.strokes.count > strokeCount {
            redoStack.removeAll() // a new stroke clears the redo history
        }
        strokeCount = drawing.strokes.count
        revision += 1
    }

    func undo() {
        guard let canvas, !canvas.drawing.strokes.isEmpty else { return }
        var d = canvas.drawing
        redoStack.append(d.strokes.removeLast())
        apply(d)
    }

    func redo() {
        guard let canvas, let stroke = redoStack.popLast() else { return }
        var d = canvas.drawing
        d.strokes.append(stroke)
        apply(d)
    }

    func clear() {
        redoStack.removeAll()
        apply(PKDrawing())
    }

    private func apply(_ d: PKDrawing) {
        isApplying = true
        canvas?.drawing = d
        isApplying = false
        strokeCount = d.strokes.count
        revision += 1
    }

    // MARK: - Reading the ink

    /// The strokes converted to line units, sampled every few screen points.
    func capturedStrokes(in layout: GuideLayout) -> [CapturedStroke] {
        drawing.strokes.map { stroke in
            let finger = InkModel.looksLikeFinger(stroke)
            var points: [CapturedPoint] = []
            for p in stroke.path.interpolatedPoints(by: .distance(3)) {
                let u = layout.toUnits(p.location.applying(stroke.transform))
                let force = finger ? -1 : min(Double(p.force) / 4.17, 1)
                points.append(CapturedPoint(x: Double(u.x), y: Double(u.y), t: p.timeOffset, force: force))
            }
            return CapturedStroke(points: points)
        }
    }

    var lastInkUsedFinger: Bool {
        drawing.strokes.contains { InkModel.looksLikeFinger($0) }
    }

    func stats(in layout: GuideLayout) -> InkStats {
        let strokes = capturedStrokes(in: layout)
        var s = InkStats()
        s.strokes = strokes.count
        s.points = strokes.reduce(0) { $0 + $1.points.count }
        let forces = strokes.flatMap { $0.points }.map(\.force).filter { $0 >= 0 }
        s.averagePressure = forces.isEmpty ? nil : forces.reduce(0, +) / Double(forces.count)
        s.usedFinger = lastInkUsedFinger
        s.seconds = strokes.reduce(0) { $0 + ($1.points.last?.t ?? 0) }
        return s
    }

    /// PencilKit does not say which input drew a stroke. Finger strokes have
    /// constant force 1 and a vertical altitude; Pencil strokes vary.
    static func looksLikeFinger(_ stroke: PKStroke) -> Bool {
        stroke.path.allSatisfy { p in
            p.force == 1 && abs(p.altitude - .pi / 2) < 0.001
        }
    }
}
