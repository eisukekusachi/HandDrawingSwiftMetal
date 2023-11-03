//
//  Canvas+Undo.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import MetalKit

extension Canvas {
    func undo() {
        undoDrawing.performUndo()
    }
    func redo() {
        undoDrawing.performRedo()
    }

    func registerDrawingUndoAction(_ currentTexture: MTLTexture) {
        registerDrawingUndoAction(with: UndoObject(texture: currentTexture))
        undoDrawing.updateUndoCount()

        if let newTexture = duplicateTexture(currentTexture) {
            layers.setTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoDrawing.registerUndo(withTarget: self) { [unowned self] _ in

            registerDrawingUndoAction(with: .init(texture: currentTexture))

            layers.setTexture(undoObject.texture)

            refreshRootTexture()
            setNeedsDisplay()
        }
    }
}
