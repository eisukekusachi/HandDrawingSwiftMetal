//
//  UndoStackModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation
import MetalKit

/// A structure that holds both `undo` and `redo` objects
struct UndoStackModel<T> {

    let undoObject: T
    let redoObject: T

    var texture: MTLTexture?

    /// Alternate swapping between `undoObject` and `redoObject`
    var reversedObject: Self {
        .init(
            undoObject: redoObject,
            redoObject: undoObject
        )
    }

}
