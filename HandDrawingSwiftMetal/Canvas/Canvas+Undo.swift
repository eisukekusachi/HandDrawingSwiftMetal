//
//  CanvasView+Undo.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/18.
//

import MetalKit

extension CanvasView {
    var canUndo: Bool {
        undoManager.canUndo
    }
    var canRedo: Bool {
        undoManager.canRedo
    }

    func clearUndo() {
        undoManager.clear()
    }
    func undo() {
        undoManager.performUndo()
    }
    func redo() {
        undoManager.performRedo()
    }

    func registerDrawingUndoAction() {
        guard let viewModel else { return }
        if viewModel.layerManager.layers.count == 0 { return }

        registerDrawingUndoAction(with: viewModel.layerManager.undoObject)
        undoManager.incrementUndoCount()

        if let newTexture = duplicateTexture(viewModel.layerManager.selectedTexture) {
            viewModel.layerManager.setTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            guard let viewModel else { return }
            if viewModel.layerManager.layers.count == 0 { return }

            registerDrawingUndoAction(with: viewModel.layerManager.undoObject)
            viewModel.layerManager.setUndoObject(undoObject)

            viewModel.layerManager.updateNonSelectedTextures()
            refreshRootTexture(commandBuffer)
            setNeedsDisplay()
        }
    }
}
