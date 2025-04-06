//
//  UndoStackObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

/// A structure that holds both `undo` and `redo` objects
struct UndoStackObject<T> {

    let undoObject: T
    let redoObject: T

    /// Alternate swapping between `undoObject` and `redoObject`
    var reversedObject: Self {
        .init(
            undoObject: redoObject,
            redoObject: undoObject
        )
    }

}
