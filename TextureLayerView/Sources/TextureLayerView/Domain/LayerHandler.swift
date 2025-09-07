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
public final class LayerHandler {

    private var textureLayers: TextureLayers?

    init(textureLayers: TextureLayers? = nil) {
        self.textureLayers = textureLayers
    }

    func insertLayer(
        layer: TextureLayerItem,
        at index: Int
    ) {
        guard let textureLayers else { return }

        textureLayers.layers.insert(layer, at: index)
    }

    func removeLayer(
        selectedLayerIndex: Int
    ) {
        guard let textureLayers else { return }

        textureLayers.layers.remove(at: selectedLayerIndex)
    }

    func moveLayer(
        indices: MoveLayerIndices
    ) {
        guard let textureLayers else { return }

        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: textureLayers.layers.count
        )

        textureLayers.layers.move(
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
        guard let textureLayers else { return }

        guard
            let selectedIndex = textureLayers.layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = textureLayers.layers[selectedIndex]

        if let title {
            textureLayers.layers[selectedIndex] = .init(
                id: layer.id,
                title: title,
                alpha: layer.alpha,
                isVisible: layer.isVisible,
                thumbnail: layer.thumbnail
            )
        }
        if let isVisible {
            textureLayers.layers[selectedIndex] = .init(
                id: layer.id,
                title: layer.title,
                alpha: layer.alpha,
                isVisible: isVisible,
                thumbnail: layer.thumbnail
            )

            // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
            textureLayers.fullCanvasUpdateSubject.send(())
        }
        if let alpha {
            textureLayers.layers[selectedIndex] = .init(
                id: layer.id,
                title: layer.title,
                alpha: alpha,
                isVisible: layer.isVisible,
                thumbnail: layer.thumbnail
            )

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            textureLayers.canvasUpdateSubject.send(())
        }
    }

    func selectLayer(id: UUID) {
        guard let textureLayers else { return }

        textureLayers.selectedLayerId = id
        textureLayers.fullCanvasUpdateSubject.send(())
    }
}
