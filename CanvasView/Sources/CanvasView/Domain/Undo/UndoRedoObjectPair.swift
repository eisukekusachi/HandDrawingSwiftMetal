//
//  UndoRedoObjectPair.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

/// A structure that holds both `undo` and `redo` objects
public struct UndoRedoObjectPair {

    let undoObject: UndoObject
    let redoObject: UndoObject

    /// Alternate swapping between `undoObject` and `redoObject`
    func reversed() -> Self{
        .init(
            undoObject: redoObject,
            redoObject: undoObject
        )
    }

    public init(undoObject: UndoObject, redoObject: UndoObject) {
        self.undoObject = undoObject
        self.redoObject = redoObject
    }
}
