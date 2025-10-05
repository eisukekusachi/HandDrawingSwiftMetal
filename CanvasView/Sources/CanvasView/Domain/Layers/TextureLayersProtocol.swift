//
//  TextureLayersProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/13.
//

import Combine
import MetalKit

/// Protocol for managing texture layers
@MainActor
public protocol TextureLayersProtocol: ObservableObject {

    /// Emits when a canvas update is requested
    var canvasUpdateRequestedPublisher: AnyPublisher<Void, Never> { get }

    /// Emits when a full canvas update is requested
    var fullCanvasUpdateRequestedPublisher: AnyPublisher<Void, Never> { get }

    /// Emits whenever `layers` change
    var layersPublisher: AnyPublisher<[TextureLayerItem], Never> { get }

    /// Emits whenever `selectedLayerId` change
    var selectedLayerIdPublisher: AnyPublisher<UUID?, Never> { get }

    /// Emits whenever `alpha` change
    var alphaPublisher: AnyPublisher<Int, Never> { get }

    /// Emits whenever `textureSize` change
    var textureSizePublisher: AnyPublisher<CGSize, Never> { get }

    var selectedLayer: TextureLayerItem? { get }

    var selectedIndex: Int? { get }

    var layers: [TextureLayerItem] { get }

    var layerCount: Int { get }

    var textureSize: CGSize { get }

    func initialize(
        configuration: ResolvedTextureLayerArrayConfiguration,
        textureRepository: TextureRepository?
    ) async

    func layer(_ layerId: UUID) -> TextureLayerItem?

    func selectLayer(_ id: UUID)

    func addNewLayer(at index: Int) async throws

    func addLayer(layer: TextureLayerModel, texture: MTLTexture, at index: Int) async throws

    func removeLayer(layerIndexToDelete index: Int) async throws

    func moveLayer(indices: MoveLayerIndices)

    func updateLayer(_ layer: TextureLayerItem)

    func updateThumbnail(_ id: UUID, texture: MTLTexture)

    func updateTitle(_ id: UUID, title: String)

    func updateVisibility(_ id: UUID, isVisible: Bool)

    func updateAlpha(_ id: UUID, alpha: Int)

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    func beginAlphaChange()

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    func endAlphaChange()

    /// Requests a partial canvas update
    func requestCanvasUpdate()

    /// Requests a full canvas update (all layers composited)
    func requestFullCanvasUpdate()

    func duplicatedTexture(_ id: UUID) async throws -> IdentifiedTexture?

    /// Adds a texture using UUID
    @discardableResult
    func addTexture(_ texture: MTLTexture, id: UUID) async throws -> IdentifiedTexture

    /// Updates an existing texture for UUID
    @discardableResult
    func updateTexture(texture: MTLTexture?, for id: UUID) async throws -> IdentifiedTexture

    /// Removes a texture with UUID
    @discardableResult
    func removeTexture(_ id: UUID) throws -> UUID
}
