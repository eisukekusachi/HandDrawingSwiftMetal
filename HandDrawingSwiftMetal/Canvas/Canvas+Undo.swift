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
        canvasDelegate?.didUndoRedo()
    }
    func redo() {
        undoManager.performRedo()
        canvasDelegate?.didUndoRedo()
    }

    func registerDrawingUndoAction(_ currentTexture: MTLTexture) {
        registerDrawingUndoAction(with: UndoObject(texture: currentTexture))

        undoManager.incrementUndoCount()
        canvasDelegate?.didUndoRedo()

        if let newTexture = duplicateTexture(currentTexture) {
            viewModel?.layerManager.setTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            guard let viewModel else { return }

            registerDrawingUndoAction(with: .init(texture: viewModel.currentTexture))

            canvasDelegate?.didUndoRedo()

            viewModel.layerManager.setTexture(undoObject.texture)

            refreshRootTexture()
            setNeedsDisplay()
        }
    }
}
