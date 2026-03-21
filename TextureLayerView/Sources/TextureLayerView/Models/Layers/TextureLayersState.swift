//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import CanvasView
import Combine
import MetalKit
import UIKit

/// A class that manages texture layers
@MainActor
public class TextureLayersState: ObservableObject {

    public var selectedLayer: TextureLayerItem? {
        guard let _selectedLayerId else { return nil }
        return _layers.first(where: { $0.id == _selectedLayerId })
    }

    public var selectedIndex: Int? {
        guard let _selectedLayerId else { return nil }
        return _layers.firstIndex(where: { $0.id == _selectedLayerId })
    }

    public var layers: [TextureLayerItem] {
        _layers
    }

    public var layerCount: Int {
        _layers.count
    }

    public var textureSize: CGSize {
        _textureSize
    }

    @Published private var _layers: [TextureLayerItem] = []

    @Published private var _selectedLayerId: LayerId?

    // Set a default value to avoid nil
    @Published private var _textureSize: CGSize = .init(width: 768, height: 1024)

    public init() {}

    public func update(
        _ textureLayers: TextureLayersModel
    ) {
        self._layers = textureLayers.layers.map { .init(model: $0) }
        self._selectedLayerId = textureLayers.selectedLayerId
        self._textureSize = textureLayers.textureSize
    }
}

public extension TextureLayersState {

    func addLayer(
        layer: TextureLayerModel,
        thumbnail: UIImage?,
        at index: Int
    ) async throws {
        self._layers.insert(
            .init(
                model: layer,
                thumbnail: thumbnail
            ),
            at: index
        )

        _selectedLayerId = layer.id
    }

    func removeLayer(layerIndexToDelete index: Int) async throws {
        guard layerCount > 1 else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return
        }

        let newLayerId = _layers[
            RemoveLayerIndex.nextLayerIndexAfterDeletion(index: index)
        ].id

        _layers.remove(at: index)

        _selectedLayerId = newLayerId
    }

    func moveLayer(indices: MoveLayerIndices) {
        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: layerCount
        )

        self._layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
    }

    func selectLayer(_ id: LayerId) {
        _selectedLayerId = id
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
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return
        }

        let layer = _layers[index]

        _layers[index] = .init(
            id: layer.id,
            title: title,
            alpha: layer.alpha,
            isVisible: layer.isVisible,
            thumbnail: layer.thumbnail
        )
    }

    func updateVisibility(_ id: LayerId, isVisible: Bool) {
        guard
            let index = index(for: id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return
        }

        let layer = _layers[index]

        _layers[index] = .init(
            id: layer.id,
            title: layer.title,
            alpha: layer.alpha,
            isVisible: isVisible,
            thumbnail: layer.thumbnail
        )
    }

    func updateAlpha(_ id: LayerId, alpha: Int) {
        guard
            let index = index(for: id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return
        }

        let layer = _layers[index]

        _layers[index] = .init(
            id: layer.id,
            title: layer.title,
            alpha: alpha,
            isVisible: layer.isVisible,
            thumbnail: layer.thumbnail
        )
    }

    func updateLayer(_ layer: TextureLayerItem) {
        guard
            let index = index(for: layer.id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return
        }

        _layers[index] = layer
    }
}

public extension TextureLayersState {

    func index(for id: LayerId) -> Int? {
        _layers.firstIndex(where: { $0.id == id })
    }

    func layer(_ id: LayerId) -> TextureLayerItem? {
        _layers.first(where: { $0.id == id })
    }

    func updateThumbnail(_ id: LayerId, texture: MTLTexture?) {
        guard
            let texture,
            let index = index(for: id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)"))
            return
        }

        let layer = _layers[index]

        self._layers[index] = .init(
           id: layer.id,
           title: layer.title,
           alpha: layer.alpha,
           isVisible: layer.isVisible,
           thumbnail: texture.makeThumbnail()
       )
    }
}
