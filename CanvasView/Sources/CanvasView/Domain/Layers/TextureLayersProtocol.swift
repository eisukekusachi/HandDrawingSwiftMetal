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
    var selectedLayerIdPublisher: AnyPublisher<LayerId?, Never> { get }

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

    func index(for id: LayerId) -> Int?

    func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture?

    func layer(_ id: LayerId) -> TextureLayerItem?

    func selectLayer(_ id: LayerId)

    func addNewLayer(at index: Int) async throws

    func addLayer(layer: TextureLayerModel, texture: MTLTexture?, at index: Int) async throws

    func removeLayer(layerIndexToDelete index: Int) async throws

    func moveLayer(indices: MoveLayerIndices)

    func updateLayer(_ layer: TextureLayerItem)

    func updateThumbnail(_ id: LayerId, texture: MTLTexture)

    func updateTitle(_ id: LayerId, title: String)

    func updateVisibility(_ id: LayerId, isVisible: Bool)

    func updateAlpha(_ id: LayerId, alpha: Int)

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    func beginAlphaChange()

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    func endAlphaChange()

    /// Requests a partial canvas update
    func requestCanvasUpdate()

    /// Requests a full canvas update (all layers composited)
    func requestFullCanvasUpdate()

    /// Updates an existing texture for LayerId
    func updateTexture(texture: MTLTexture?, for id: LayerId) async throws
}
