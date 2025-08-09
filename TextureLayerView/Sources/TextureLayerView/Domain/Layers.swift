//
//  Layers.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/08.
//

import CanvasView
import MetalKit

enum Layers {

    static func insertLayer(
        canvasState: CanvasState?,
        layer: TextureLayerItem,
        texture: MTLTexture?,
        at index: Int
    ) {
        guard let canvasState else { return }

        canvasState.layers.insert(
            .init(
                item: layer,
                thumbnail: texture?.makeThumbnail()
            ),
            at: index
        )
        canvasState.selectedLayerId = layer.id
        canvasState.fullCanvasUpdateSubject.send(())
    }

    static func removeLayer(
        canvasState: CanvasState?,
        selectedLayerIndex: Int,
        selectedLayer: TextureLayerModel
    ) {
        guard let canvasState else { return }

        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedLayerIndex)

        canvasState.layers.remove(at: selectedLayerIndex)
        canvasState.selectedLayerId = canvasState.layers[newLayerIndex].id
        canvasState.fullCanvasUpdateSubject.send(())
    }

    static func moveLayer(
        canvasState: CanvasState?,
        indices: MoveLayerIndices
    ) {
        guard let canvasState else { return }

        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: canvasState.layers.count
        )

        canvasState.layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
        canvasState.fullCanvasUpdateSubject.send(())
    }

    static func updateLayer(
        canvasState: CanvasState?,
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard let canvasState else { return }

        guard
            let selectedIndex = canvasState.layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = canvasState.layers[selectedIndex]

        if let title {
            canvasState.layers[selectedIndex] = .init(
                id: layer.id,
                thumbnail: layer.thumbnail,
                title: title,
                alpha: layer.alpha,
                isVisible: layer.isVisible
            )
        }
        if let isVisible {
            canvasState.layers[selectedIndex] = .init(
                id: layer.id,
                thumbnail: layer.thumbnail,
                title: layer.title,
                alpha: layer.alpha,
                isVisible: isVisible
            )

            // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
            canvasState.fullCanvasUpdateSubject.send(())
        }
        if let alpha {
            canvasState.layers[selectedIndex] = .init(
                id: layer.id,
                thumbnail: layer.thumbnail,
                title: layer.title,
                alpha: alpha,
                isVisible: layer.isVisible
            )

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            canvasState.canvasUpdateSubject.send(())
        }
    }

    static func selectLayer(canvasState: CanvasState?, layerId: UUID) {
        guard let canvasState else { return }

        canvasState.selectedLayerId = layerId
        canvasState.fullCanvasUpdateSubject.send(())
    }
}
