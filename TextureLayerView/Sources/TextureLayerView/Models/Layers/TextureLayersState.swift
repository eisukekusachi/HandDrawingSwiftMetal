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
public class TextureLayersState: ObservableObject {

    public var selectedLayer: TextureLayerItem? {
        guard let _selectedLayerId else { return nil }
        return _layers.first(where: { $0.id == _selectedLayerId })
    }

    public var selectedIndex: Int? {
        guard let _selectedLayerId else { return nil }
        return _layers.firstIndex(where: { $0.id == _selectedLayerId })
    }

    public let device: MTLDevice

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

    @Published private var _alpha: Int = 255

    private var oldAlpha: Int?

    public init(
        device: MTLDevice
    ) {
        self.device = device
    }

    public func addNewLayer(at index: Int) async throws {
        guard
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else { return }

        try await addLayer(
            layer: .init(
                id: LayerId(),
                title: TimeStampFormatter.currentDate,
                alpha: 255,
                isVisible: true
            ),
            newTexture: newTexture,
            at: index
        )
    }

    public func addLayer(layer: TextureLayerModel, newTexture: MTLTexture?, at index: Int) async throws {
        guard
            // If a texture is provided as an argument, use it. otherwise create a new one.
            let newTexture: MTLTexture = newTexture ?? MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else { return }

        self._layers.insert(
            .init(
                model: layer,
                thumbnail: newTexture.makeThumbnail()
            ),
            at: index
        )

        _selectedLayerId = layer.id
    }

    public func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            let selectedLayerId = selectedLayer?.id,
            layerCount > 1
        else {
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

    public func moveLayer(indices: MoveLayerIndices) {
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

    public func selectLayer(_ id: LayerId) {
        _selectedLayerId = id
    }

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    public func beginAlphaChange() {
        // Do nothing
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    public func endAlphaChange() {
        // Do nothing
    }

    public func updateTitle(_ id: LayerId, title: String) {
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

    public func updateVisibility(_ id: LayerId, isVisible: Bool) {
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

    public func updateAlpha(_ id: LayerId, alpha: Int) {
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

        _alpha = alpha
    }

    public func updateLayer(_ layer: TextureLayerItem) {
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

extension TextureLayersState {
    public func update(
        _ textureLayers: TextureLayersModel
    ) {
        self._layers = textureLayers.layers.map { .init(model: $0) }
        self._selectedLayerId = textureLayers.selectedLayerId
        self._textureSize = textureLayers.textureSize
    }

    public func index(for id: LayerId) -> Int? {
        _layers.firstIndex(where: { $0.id == id })
    }

    public func layer(_ id: LayerId) -> TextureLayerItem? {
        _layers.first(where: { $0.id == id })
    }

    public func updateThumbnail(_ id: LayerId, texture: MTLTexture?) {
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
