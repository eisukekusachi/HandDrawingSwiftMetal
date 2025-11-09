//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// A class that manages texture layers
public class TextureLayers: TextureLayersProtocol, ObservableObject {

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

    /// Emits whenever `layers` change such as when layers are added or removed
    public var layersPublisher: AnyPublisher<[TextureLayerItem], Never> {
        $_layers.eraseToAnyPublisher()
    }

    /// Emits whenever `selectedLayerId` change
    public var selectedLayerIdPublisher: AnyPublisher<LayerId?, Never> {
        $_selectedLayerId.eraseToAnyPublisher()
    }

    /// Emits whenever `alpha` change
    public var alphaPublisher: AnyPublisher<Int, Never> {
        $_alpha.eraseToAnyPublisher()
    }

    /// Emits whenever `textureSize` change
    public var textureSizePublisher: AnyPublisher<CGSize, Never> {
        $_textureSize.eraseToAnyPublisher()
    }

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

    private var canvasRenderer: CanvasRenderer?

    private var textureRepository: TextureRepository?

    @Published private var _layers: [TextureLayerItem] = []

    @Published private var _selectedLayerId: LayerId?

    // Set a default value to avoid nil
    @Published private var _textureSize: CGSize = .init(width: 768, height: 1024)

    @Published private var _alpha: Int = 255

    private var oldAlpha: Int?

    public init(
        canvasRenderer: CanvasRenderer? = nil
    ) {
        self.canvasRenderer = canvasRenderer
    }

    public func initialize(
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

    public func addNewLayer(at index: Int) async throws {
        guard
            let device = canvasRenderer?.device,
            let texture = MTLTextureCreator.makeTexture(
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
            texture: texture,
            at: index
        )
    }

    public func addLayer(layer: TextureLayerModel, texture: MTLTexture?, at index: Int) async throws {
        guard
            let textureRepository
        else { return }

        // If a texture is provided as an argument, use it. otherwise create a new one.
        var newTexture: MTLTexture? = texture

        if newTexture == nil, let device = canvasRenderer?.device {
            newTexture = MTLTextureCreator.makeTexture(
                width: Int(_textureSize.width),
                height: Int(_textureSize.height),
                with: device
            )
        }

        guard let newTexture else { return }

        self._layers.insert(
            .init(
                model: layer,
                thumbnail: newTexture.makeThumbnail()
            ),
            at: index
        )

        _selectedLayerId = layer.id

        try await textureRepository
            .addTexture(
                newTexture,
                id: layer.id
            )
    }

    public func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            layerCount > 1,
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

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    public func beginAlphaChange() {
        // Do nothing
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    public func endAlphaChange() {
        // Do nothing
    }

    /// Copies a texture for the given `LayerId`
    public func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture? {
        try await textureRepository?.duplicatedTexture(id)
    }

    public func index(for id: LayerId) -> Int? {
        _layers.firstIndex(where: { $0.id == id })
    }

    public func layer(_ id: LayerId) -> TextureLayerItem? {
        _layers.first(where: { $0.id == id })
    }

    public func selectLayer(_ id: LayerId) {
        _selectedLayerId = id
    }

    public func updateLayer(_ layer: TextureLayerItem) {
        guard
            let index = index(for: layer.id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
            return
        }

        _layers[index] = layer
    }

    public func updateThumbnail(_ id: LayerId, texture: MTLTexture) {
        guard
            let index = index(for: id)
        else {
            let value: String = "index: \(String(describing: index))"
            Logger.error(String(localized: "Unable to find \(value)", bundle: .module))
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

    public func updateTitle(_ id: LayerId, title: String) {
        guard
            let index = index(for: id)
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

    public func updateVisibility(_ id: LayerId, isVisible: Bool) {
        guard
            let index = index(for: id)
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

    public func updateAlpha(_ id: LayerId, alpha: Int) {
        guard
            let index = index(for: id)
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

    public func updateTexture(texture: MTLTexture, for id: LayerId) async throws {
        guard let textureRepository else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to find \("textureRepository")", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
        try await textureRepository.updateTexture(texture: texture, for: id)
    }

    /// Requests a partial canvas update
    public func requestCanvasUpdate() {
        canvasUpdateRequestedSubject.send(())
    }

    /// Requests a full canvas update (all layers composited)
    public func requestFullCanvasUpdate() {
        fullCanvasUpdateRequestedSubject.send(())
    }
}
