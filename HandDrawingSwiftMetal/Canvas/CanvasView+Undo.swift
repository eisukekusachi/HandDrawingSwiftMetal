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
        
        if viewModel.drawingTool.layerManager.layers.count == 0 { return }

        registerDrawingUndoAction(with: viewModel.undoObject)
        undoManager.incrementUndoCount()

        if  let selectedTexture = viewModel.drawingTool.layerManager.selectedTexture,
            let newTexture = MTKTextureUtils.duplicateTexture(viewModel.device, selectedTexture) {
            viewModel.drawingTool.layerManager.updateSelectedLayerTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self as CanvasView) { [unowned self] _ in
            guard let viewModel else { return }
            if viewModel.drawingTool.layerManager.layers.count == 0 { return }

            registerDrawingUndoAction(with: viewModel.undoObject)

            viewModel.drawingTool.layerManager.update(undoObject: undoObject)

            viewModel.drawingTool.layerManager.addCommandToMergeUnselectedLayers(
                to: commandBuffer
            )
            viewModel.drawingTool.addCommandToMergeAllLayers(
                onto: rootTexture,
                to: commandBuffer
            )

            viewModel.drawingTool.setNeedsDisplay()
        }
    }
}
