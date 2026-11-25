import PencilKit
import SwiftUI

/// A transparent PencilKit canvas with a fixed monoline pen.
struct InkCanvas: UIViewRepresentable {
    @ObservedObject var model: InkModel
    var lineWidth: CGFloat = 5

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.drawingPolicy = model.pencilOnly ? .pencilOnly : .anyInput
        view.tool = PKInkingTool(.monoline, color: .black, width: lineWidth)
        view.delegate = context.coordinator
        model.canvas = view
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.drawingPolicy = model.pencilOnly ? .pencilOnly : .anyInput
        if model.canvas !== view {
            model.canvas = view
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let model: InkModel

        init(model: InkModel) {
            self.model = model
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            model.drawingDidChange(canvasView.drawing)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            model.setDrawing(true)
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            model.setDrawing(false)
        }
    }
}
