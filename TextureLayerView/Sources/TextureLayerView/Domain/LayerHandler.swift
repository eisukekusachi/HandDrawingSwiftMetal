//
//  LayerHandler.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/08.
//

import CanvasView
import MetalKit

/// /// A class responsible for managing layer operations and updating the CanvasState accordingly.
@MainActor
final class LayerHandler {

    private var canvasState: CanvasState?

    init(canvasState: CanvasState? = nil) {
        self.canvasState = canvasState
    }

    func insertLayer(
        layer: TextureLayerItem,
        thumbnail: UIImage?,
        at index: Int
    ) {
        guard let canvasState else { return }

        canvasState.layers.insert(
            .init(
                item: layer,
                thumbnail: thumbnail
            ),
            at: index
        )
    }

    func removeLayer(
        selectedLayerIndex: Int
    ) {
        guard let canvasState else { return }

        canvasState.layers.remove(at: selectedLayerIndex)
    }

    func moveLayer(
        indices: MoveLayerIndices
    ) {
        guard let canvasState else { return }

        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: canvasState.layers.count
        )

        canvasState.layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
    }

    func updateLayer(
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

    func selectLayer(id: UUID) {
        guard let canvasState else { return }

        canvasState.selectedLayerId = id
        canvasState.fullCanvasUpdateSubject.send(())
    }
}
