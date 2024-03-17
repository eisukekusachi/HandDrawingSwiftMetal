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
        if viewModel.parameters.layerManager.layers.count == 0 { return }

        registerDrawingUndoAction(with: viewModel.undoObject)
        undoManager.incrementUndoCount()

        if  let selectedLayer = viewModel.parameters.layerManager.selectedLayer,
            let newTexture = MTKTextureUtils.duplicateTexture(viewModel.device, viewModel.parameters.layerManager.selectedTexture) {
            viewModel.parameters.layerManager.updateTexture(selectedLayer, newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            guard let viewModel else { return }
            if viewModel.parameters.layerManager.layers.count == 0 { return }

            registerDrawingUndoAction(with: viewModel.undoObject)

            viewModel.parameters.layerManager.index = undoObject.index
            viewModel.parameters.layerManager.layers = undoObject.layers

            viewModel.parameters.layerManager.updateNonSelectedTextures(commandBuffer: commandBuffer)
            viewModel.mergeAllLayers(to: rootTexture,
                                     commandBuffer)
            
            viewModel.parameters.setNeedsDisplaySubject.send()
        }
    }
}
