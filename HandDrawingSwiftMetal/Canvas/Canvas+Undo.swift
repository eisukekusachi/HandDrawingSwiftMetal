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

    func registerDrawingUndoAction(_ currentTexture: MTLTexture) {
        registerDrawingUndoAction(with: UndoObject(texture: currentTexture))

        undoManager.incrementUndoCount()

        if let newTexture = duplicateTexture(currentTexture) {
            viewModel?.setCurrentTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            guard let viewModel else { return }

            registerDrawingUndoAction(with: .init(texture: viewModel.currentTexture))

            viewModel.setCurrentTexture(undoObject.texture)

            refreshRootTexture(commandBuffer)
            setNeedsDisplay()
        }
    }
}
