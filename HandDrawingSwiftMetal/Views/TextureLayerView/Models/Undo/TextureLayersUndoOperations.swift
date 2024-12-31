//
//  TextureLayersUndoOperations.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

extension TextureLayers {
    func updateLayersWithUndoObject(_ undoObject: TextureLayerUndoObject, completion: (() -> Void)?) {
        switch undoObject.undoAction {
        case .drawing(let index):
            undoLayerDrawing(
                index: index,
                selectedIndex: undoObject.selectedIndexAfterUndo,
                layer: undoObject.textureLayer?.getLayerWithNewTexture(device: device)
            )

        case .insert(let index):
            undoLayerInsert(
                index: index,
                selectedIndex: undoObject.selectedIndexAfterUndo,
                layer: undoObject.textureLayer?.getLayerWithNewTexture(device: device)
            )

        case .remove(let index):
            undoLayerRemove(
                index: index,
                selectedIndex: undoObject.selectedIndexAfterUndo
            )

        case .move(let fromIndex, let toIndex):
            moveLayer(
                fromIndex: fromIndex,
                toIndex: toIndex,
                selectedIndex: undoObject.selectedIndexAfterUndo,
                layer: undoObject.textureLayer?.getLayerWithNewTexture(device: device)
            )

        case .edit(let index):
            undoLayerEdit(
                index: index,
                selectedIndex: undoObject.selectedIndexAfterUndo,
                layer: undoObject.textureLayer
            )
        }

        completion?()
    }

    func undoLayerDrawing(
        index: Int,
        selectedIndex: Int,
        layer: TextureLayer?
    ) {
        guard let layer else { return }
        setLayer(
            index: index,
            layer: layer.getLayerWithNewTexture(device: device)
        )
        setIndex(selectedIndex)
        layers[index].updateThumbnail()
    }

    func undoLayerInsert(
        index: Int,
        selectedIndex: Int,
        layer: TextureLayer?
    ) {
        guard let layer else { return }
        insertLayer(
            layer: layer.getLayerWithNewTexture(device: device),
            at: index
        )
        setIndex(selectedIndex)
        layers[index].updateThumbnail()
    }

    func undoLayerRemove(
        index: Int,
        selectedIndex: Int
    ) {
        removeLayer(
            at: index
        )
        setIndex(selectedIndex)
    }

    func undoLayerEdit(
        index: Int,
        selectedIndex: Int,
        layer: TextureLayer?
    ) {
        guard let layer else { return }
        updateLayer(
            index: index,
            title: layer.title,
            isVisible: layer.isVisible,
            alpha: layer.alpha
        )
        setIndex(selectedIndex)
        layers[index].updateThumbnail()
    }

    func moveLayer(
        fromIndex: Int,
        toIndex: Int,
        selectedIndex: Int,
        layer: TextureLayer?
    ) {
        guard let layer else { return }
        insertLayer(layer: layer, at: toIndex)
        removeLayer(at: fromIndex)
        setIndex(selectedIndex)
    }

    static func getReversedIndex(index: Int, layerCount: Int) -> Int {
        // In drawing applications, textures are stacked on top of each other,
        // so TextureLayers are arranged in the reverse order of SwiftUI's List.
        (layerCount - 1) - index
    }

}
