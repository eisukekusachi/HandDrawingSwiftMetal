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

        if  let selectedTexture = viewModel.parameters.layerManager.selectedTexture,
            let newTexture = MTKTextureUtils.duplicateTexture(viewModel.device, selectedTexture) {
            viewModel.parameters.layerManager.updateSelectedLayerTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            guard let viewModel else { return }
            if viewModel.parameters.layerManager.layers.count == 0 { return }

            registerDrawingUndoAction(with: viewModel.undoObject)

            viewModel.parameters.layerManager.update(undoObject: undoObject)

            viewModel.parameters.layerManager.addCommandToMergeUnselectedLayers(
                to: commandBuffer
            )
            viewModel.parameters.addCommandToMergeAllLayers(
                onto: rootTexture,
                to: commandBuffer
            )

            viewModel.parameters.commitCommandsInCommandBuffer.send()
        }
    }
}
