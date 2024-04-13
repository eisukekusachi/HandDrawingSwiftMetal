//
//  CanvasView+Undo.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/18.
//

import MetalKit

extension CanvasView {
    var canUndo: Bool {
        undoManagerWithCount.canUndo
    }
    var canRedo: Bool {
        undoManagerWithCount.canRedo
    }

    func clearUndo() {
        undoManagerWithCount.clear()
    }
    func undo() {
        undoManagerWithCount.performUndo()
    }
    func redo() {
        undoManagerWithCount.performRedo()
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject, target: UIView) {
        undoManagerWithCount.registerUndo(withTarget: target) { [unowned self] _ in
            guard
                let viewModel,
                viewModel.layerManager.layers.count != 0
            else { return }

            registerDrawingUndoAction(with: viewModel.undoObject, target: target)

            viewModel.refreshCanvas(using: undoObject)
        }
    }

}
