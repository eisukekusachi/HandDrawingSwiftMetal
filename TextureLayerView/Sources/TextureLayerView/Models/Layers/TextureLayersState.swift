//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import MetalKit
import UIKit

/// A class that manages texture layers
@MainActor
public class TextureLayersState: ObservableObject {

    public var selectedLayer: TextureLayerItem? {
        guard let selectedLayerId else { return nil }
        return layers.first(where: { $0.id == selectedLayerId })
    }

    public var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    public var layerCount: Int {
        layers.count
    }

    @Published public private(set) var layers: [TextureLayerItem] = []

    @Published public private(set) var selectedLayerId: LayerId?

    // Set a default value to avoid nil
    @Published public private(set) var textureSize: CGSize = .init(width: 768, height: 1024)

    public init() {}

    public func update(
        _ textureLayers: TextureLayersModel
    ) {
        self.layers = textureLayers.layers.map { .init(model: $0) }
        self.selectedLayerId = textureLayers.selectedLayerId
        self.textureSize = textureLayers.textureSize
    }
}

public extension TextureLayersState {

    func addLayer(
        layer: TextureLayerModel,
        thumbnail: UIImage?,
        at index: Int
    ) {
        layers.insert(
            .init(
                model: layer,
                thumbnail: thumbnail
            ),
            at: index
        )

        selectedLayerId = layer.id
    }

    @discardableResult
    func removeLayer(layerIndexToDelete index: Int) -> Bool {
        guard layerCount > 1 else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return false
        }

        let newLayerId = layers[
            RemoveLayerIndex.nextLayerIndexAfterDeletion(index: index)
        ].id

        layers.remove(at: index)

        selectedLayerId = newLayerId

        return true
    }

    func moveLayer(indices: MoveLayerIndices) {
        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: layerCount
        )

        layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
    }

    func selectLayer(_ id: LayerId) {
        selectedLayerId = id
    }

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    func beginAlphaChange() {
        // Do nothing
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    func endAlphaChange() {
        // Do nothing
    }

    func updateTitle(_ id: LayerId, title: String) {
        guard
            let index = index(for: id)
        else {
            Logger.error(String(localized: "Unable to find \(id.uuidString)"))
            return
        }

        let layer = layers[index]

        layers[index] = .init(
            id: layer.id,
            title: title,
            alpha: layer.alpha,
            isVisible: layer.isVisible,
            thumbnail: layer.thumbnail
        )
    }

    func updateLayer(_ layer: TextureLayerItem) {
        guard
            let index = index(for: layer.id)
        else {
            Logger.error(String(localized: "Unable to find \(layer.id.uuidString)"))
            return
        }

        layers[index] = layer
    }
    
    func update(
        _ id: LayerId,
        title: String? = nil,
        alpha: Int? = nil,
        isVisible: Bool? = nil,
        thumbnail: UIImage? = nil
    ) {
        guard
            let index = index(for: id)
        else {
            Logger.error(String(localized: "Unable to find \(id.uuidString)"))
            return
        }

        let layer = layers[index]
        layers[index] = layer.updated(
            title: title,
            alpha: alpha,
            isVisible: isVisible,
            thumbnail: thumbnail
        )
    }

    func updateAlpha(_ id: LayerId, alpha: Int) {
        guard
            let index = index(for: id)
        else {
            Logger.error(String(localized: "Unable to find \(id.uuidString)"))
            return
        }

        let layer = layers[index]
        layers[index] = layer.updated(alpha: alpha)
    }

    func updateThumbnail(_ id: LayerId, texture: MTLTexture?) {
        guard let texture else {
            Logger.error(String(localized: "Unable to find texture for \(id.uuidString)"))
            return
        }
        guard let index = index(for: id) else {
            Logger.error(String(localized: "Unable to find \(id.uuidString)"))
            return
        }

        let layer = layers[index]
        self.layers[index] = layer.updated(thumbnail: texture.makeThumbnail())
    }

    func index(for id: LayerId) -> Int? {
        layers.firstIndex(where: { $0.id == id })
    }

    func layer(_ id: LayerId) -> TextureLayerItem? {
        layers.first(where: { $0.id == id })
    }
}
