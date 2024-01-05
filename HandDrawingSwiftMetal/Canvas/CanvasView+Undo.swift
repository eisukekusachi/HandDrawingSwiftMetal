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

        registerDrawingUndoAction(with: viewModel.undoObject)
        undoManager.incrementUndoCount()

        if  let selectedLayer = viewModel.layerManager.selectedLayer,
            let newTexture = duplicateTexture(viewModel.layerManager.selectedTexture) {
            viewModel.layerManager.updateSelectedTexture(selectedLayer, newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            guard let viewModel else { return }
            if viewModel.layerManager.layers.count == 0 { return }

            registerDrawingUndoAction(with: viewModel.undoObject)

            viewModel.layerManager.index = undoObject.index
            viewModel.layerManager.layers = undoObject.layers
            viewModel.layerManager.selectedLayerAlpha = undoObject.layers[undoObject.index].alpha

            viewModel.layerManager.updateNonSelectedTextures()
            refreshCanvas()
        }
    }
}