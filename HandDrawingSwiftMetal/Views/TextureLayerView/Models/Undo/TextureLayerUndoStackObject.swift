//
//  TextureLayerUndoStackObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

extension UndoStackObject<TextureLayerUndoObject> {

    init(insertIndex: Int, textureLayer: TextureLayer) {
        undoObject = .init(
            removeIndex: insertIndex
        )
        redoObject = .init(
            insertIndex: insertIndex,
            textureLayer: textureLayer
        )
    }

    init(removeIndex: Int, textureLayer: TextureLayer) {
        undoObject = .init(
            insertIndex: removeIndex,
            textureLayer: textureLayer
        )
        redoObject = .init(
            removeIndex: removeIndex
        )
    }

    init(
        fromIndex: Int,
        toIndex: Int,
        selectedIndex: Int,
        selectedIndexAfterMove: Int,
        textureLayer: TextureLayer
    ) {
        undoObject = .init(
            fromIndex: fromIndex,
            toIndex: toIndex,
            moveSelectedIndex: selectedIndex,
            textureLayer: textureLayer
        )

        // Undoing an Undo results in a Redo, so the values are swapped
        redoObject = .init(
            fromIndex: toIndex,
            toIndex: fromIndex,
            moveSelectedIndex: selectedIndexAfterMove,
            textureLayer: textureLayer
        )
    }

}
