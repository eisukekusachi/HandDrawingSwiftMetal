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

        if let device: MTLDevice = MTLCreateSystemDefaultDevice(),
           let selectedTexture = viewModel.layerManager.selectedTexture,
           let newTexture = MTKTextureUtils.duplicateTexture(device, selectedTexture) {
            viewModel.layerManager.updateSelectedLayerTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self as CanvasView) { [unowned self] _ in
            guard let viewModel else { return }
            if viewModel.layerManager.layers.count == 0 { return }

            registerDrawingUndoAction(with: viewModel.undoObject)

            viewModel.layerManager.update(undoObject: undoObject)

            viewModel.layerManager.addMergeUnselectedLayersCommands(
                to: commandBuffer
            )
            viewModel.layerManager.addMergeAllLayersCommands(
                backgroundColor: self.backgroundColor ?? .white,
                onto: rootTexture,
                to: commandBuffer
            )

            self.setNeedsDisplay()
        }
    }
}
