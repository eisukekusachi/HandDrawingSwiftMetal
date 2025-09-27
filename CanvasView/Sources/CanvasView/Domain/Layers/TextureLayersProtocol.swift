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

    func duplicatedTexture(id: UUID) async throws -> IdentifiedTexture?

    func selectLayer(id: UUID)

    /// Adds a texture using UUID
    @discardableResult
    func addTexture(_ texture: MTLTexture, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture

    /// Updates an existing texture for UUID
    @discardableResult
    func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture

    /// Removes a texture with UUID
    @discardableResult
    func removeTexture(_ uuid: UUID) throws -> UUID

    func addLayer(layer: TextureLayerItem, texture: MTLTexture, at index: Int) async throws

    func removeLayer(layerIndexToDelete index: Int) async throws

    func moveLayer(indices: MoveLayerIndices)

    func updateLayer(_ layer: TextureLayerItem)

    func updateTitle(id: UUID, title: String)

    func updateVisibility(id: UUID, isVisible: Bool)

    func updateAlpha(id: UUID, alpha: Int)

    func updateThumbnail(_ identifiedTexture: IdentifiedTexture)

    /// Requests a partial canvas update
    func requestCanvasUpdate()

    /// Requests a full canvas update (all layers composited)
    func requestFullCanvasUpdate()
}
