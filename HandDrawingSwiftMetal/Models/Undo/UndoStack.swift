//
//  UndoStack.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation
import Combine

final class UndoStack<T> {

    let undoManager: UndoManager

    let sendUndoData = PassthroughSubject<T, Never>()

    var undoObject: T?
    var redoObject: T?

    init(undoManager: UndoManager, undoCount: Int = 64) {
        self.undoManager = undoManager
        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false
    }

    var canUndo: Bool {
        undoManager.canUndo
    }
    var canRedo: Bool {
        undoManager.canRedo
    }

    func undo() {
        undoManager.undo()
    }
    func redo() {
        undoManager.redo()
    }
    func reset() {
        undoManager.removeAllActions()
    }

    func clearObjects() {
        undoObject = nil
        redoObject = nil
    }

    func pushUndoObject(
        _ undoStackObject: UndoStackObject<T>
    ) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.sendUndoData.send(undoStackObject.undoObject)

            // Redo Registration
            self?.pushUndoObject(
                undoStackObject.reversedObject
            )
        }
        undoManager.endUndoGrouping()
    }

}
