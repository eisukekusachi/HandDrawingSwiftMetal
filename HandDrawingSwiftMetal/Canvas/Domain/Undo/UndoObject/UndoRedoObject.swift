//
//  UndoRedoObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/27.
//

import MetalKit

struct UndoRedoObject {
    var undoObject: UndoObject
    var redoObject: UndoObject
    var texture: MTLTexture?
}
