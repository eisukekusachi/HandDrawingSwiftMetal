//
//  TextureLayerUndoObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation
import MetalKit

struct TextureLayerUndoObject {

    let undoAction: TextureLayerUndoAction

    var textureLayer: TextureLayer? = nil

    let selectedIndexAfterUndo: Int
}

extension TextureLayerUndoObject {

    init(
        drawingIndex index: Int,
        textureLayer: TextureLayer
    ) {
        self.undoAction = .drawing(index: index)
        self.textureLayer = textureLayer
        self.selectedIndexAfterUndo = index
    }

    init(
        insertIndex index: Int,
        textureLayer: TextureLayer,
        selectedIndex: Int? = nil
    ) {
        self.undoAction = .insert(index: index)
        self.textureLayer = textureLayer
        self.selectedIndexAfterUndo = selectedIndex ?? index
    }

    init(
        removeIndex index: Int
    ) {
        self.undoAction = .remove(index: index)
        self.selectedIndexAfterUndo = index
    }

    init(
        editIndex index: Int,
        textureLayer: TextureLayer,
        selectedIndex: Int? = nil
    ) {
        self.undoAction = .edit(index: index)
        self.textureLayer = textureLayer
        self.selectedIndexAfterUndo = selectedIndex ?? index
    }

    init(
        fromIndex: Int,
        toIndex: Int,
        moveSelectedIndex: Int,
        textureLayer: TextureLayer
    ) {
        self.undoAction = .move(
            fromIndex: fromIndex,
            toIndex: toIndex
        )
        self.textureLayer = textureLayer
        self.selectedIndexAfterUndo = moveSelectedIndex
    }

}
