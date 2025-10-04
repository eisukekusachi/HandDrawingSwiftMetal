//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// A class that manages texture layers
public final class TextureLayers: TextureLayersProtocol, ObservableObject {

    /// Emits when a canvas update is requested
    public var canvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        canvasUpdateRequestedSubject.eraseToAnyPublisher()
    }
    private let canvasUpdateRequestedSubject = PassthroughSubject<Void, Never>()

    /// Emits when a full canvas update is requested
    public var fullCanvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        fullCanvasUpdateRequestedSubject.eraseToAnyPublisher()
    }
    private let fullCanvasUpdateRequestedSubject = PassthroughSubject<Void, Never>()

    /// Emits whenever `layers` change
    public var layersPublisher: AnyPublisher<[TextureLayerItem], Never> {
        $_layers.eraseToAnyPublisher()
    }

    /// Emits whenever `selectedLayerId` change
    public var selectedLayerIdPublisher: AnyPublisher<UUID?, Never> {
        $_selectedLayerId.eraseToAnyPublisher()
    }

    /// Emits whenever `textureSize` change
    public var textureSizePublisher: AnyPublisher<CGSize, Never> {
        $_textureSize.eraseToAnyPublisher()
    }

    /// Emits whenever `alpha` change
    public var alphaPublisher: AnyPublisher<Int, Never> {
        $_alpha.eraseToAnyPublisher()
    }

    public var textureSize: CGSize {
        _textureSize
    }

    public var layers: [TextureLayerItem] {
        _layers
    }

    public var layerCount: Int {
        _layers.count
    }

    public var selectedLayerId: UUID? {
        _selectedLayerId
    }

    public var selectedLayer: TextureLayerItem? {
        guard let _selectedLayerId else { return nil }
        return _layers.first(where: { $0.id == _selectedLayerId })
    }

    public var selectedIndex: Int? {
        guard let _selectedLayerId else { return nil }
        return _layers.firstIndex(where: { $0.id == _selectedLayerId })
    }

    private var textureRepository: TextureRepository?

    @Published private var _layers: [TextureLayerItem] = []

    @Published private var _selectedLayerId: UUID?

    // Set a default value to avoid nil
    @Published private var _textureSize: CGSize = .init(width: 768, height: 1024)

    @Published private var _alpha: Int = 255

    private var oldAlpha: Int?

    public init() {}
}

public extension TextureLayers {

    func initialize(
        configuration: ResolvedTextureLayerArrayConfiguration,
        textureRepository: TextureRepository? = nil
    ) async {
        self._textureSize = configuration.textureSize

        self._layers = configuration.layers.map {
            .init(
                id: $0.id,
                title: $0.title,
                alpha: $0.alpha,
                isVisible: $0.isVisible,
                thumbnail: nil
            )
        }

        self._selectedLayerId = configuration.selectedLayerId

        self.textureRepository = textureRepository

        Task {
            let textures = try await textureRepository?.duplicatedTextures(_layers.map { $0.id })
            textures?.forEach { [weak self] identifiedTexture in
                self?.updateThumbnail(identifiedTexture.id, texture: identifiedTexture.texture)
            }
        }
    }

    func layer(_ id: UUID) -> TextureLayerItem? {
        _layers.first(where: { $0.id == id })
    }

    func selectLayer(_ id: UUID) {
        _selectedLayerId = id
    }

    func addLayer(layer: TextureLayerItem, texture: MTLTexture, at index: Int) async throws {
        guard let textureRepository else { return }

        self._layers.insert(layer, at: index)

        _selectedLayerId = layer.id

        try await textureRepository
            .addTexture(
                texture,
                id: layer.id
            )
    }

    func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            _layers.count > 1,
            let textureRepository,
            let selectedLayerId = selectedLayer?.id
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
            return
        }

        let newLayerId = _layers[
            RemoveLayerIndex.nextLayerIndexAfterDeletion(index: index)
        ].id

        _layers.remove(at: index)

        _selectedLayerId = newLayerId

        try textureRepository
            .removeTexture(selectedLayerId)
    }

    func moveLayer(indices: MoveLayerIndices) {
        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: self._layers.count
        )

        self._layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
    }

    func updateLayer(_ layer: TextureLayerItem) {
        guard
            let index = _layers.firstIndex(where: { $0.id == layer.id })
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
            return
        }

        _layers[index] = layer
    }

    func updateThumbnail(_ id: UUID, texture: MTLTexture) {
        guard
            let index = _layers.firstIndex(where: { $0.id == id })
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
            return
        }

        self._layers[index].thumbnail = texture.makeThumbnail()
    }

    func updateTitle(_ id: UUID, title: String) {
        guard
            let index = _layers.map({ $0.id }).firstIndex(of: id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
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

    func updateVisibility(_ id: UUID, isVisible: Bool) {
        guard
            let index = _layers.firstIndex(where: { $0.id == id })
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
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

    func updateAlpha(_ id: UUID, alpha: Int) {
        guard
            let index = _layers.firstIndex(where: { $0.id == id })
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
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

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    func beginAlphaChange() {
        // Do nothing
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    func endAlphaChange() {
        // Do nothing
    }

    /// Requests a partial canvas update
    func requestCanvasUpdate() {
        canvasUpdateRequestedSubject.send(())
    }

    /// Requests a full canvas update (all layers composited)
    func requestFullCanvasUpdate() {
        fullCanvasUpdateRequestedSubject.send(())
    }
}

public extension TextureLayers {
    /// Copies a texture for the given UUID
    func duplicatedTexture(_ id: UUID) async throws -> IdentifiedTexture? {
        try await textureRepository?.duplicatedTexture(id)
    }

    func addTexture(_ texture: any MTLTexture, id: UUID) async throws -> IdentifiedTexture {
        guard let textureRepository else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to find \("textureRepository")", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
        return try await textureRepository.addTexture(texture, id: id)
    }

    func updateTexture(texture: (any MTLTexture)?, for id: UUID) async throws -> IdentifiedTexture {
        guard let textureRepository else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to find \("textureRepository")", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
        return try await textureRepository.updateTexture(texture: texture, for: id)
    }

    func removeTexture(_ id: UUID) throws -> UUID {
        guard let textureRepository else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to find \("textureRepository")", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
        return try textureRepository.removeTexture(id)
    }
}
