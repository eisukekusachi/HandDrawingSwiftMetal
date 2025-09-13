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

    var selectedLayer: TextureLayerItem? { get }

    var selectedIndex: Int? { get }

    var textureSize: CGSize { get }

    var layerCount: Int { get }

    func layer(_ layerId: UUID) -> TextureLayerItem?

    func selectLayer(id: UUID)

    func addLayer(layer: TextureLayerItem,texture: MTLTexture?,at index: Int) async throws

    func removeLayer(layerIndexToDelete index: Int) async throws

    func moveLayer( indices: MoveLayerIndices)

    func updateTitle(id: UUID, title: String)

    func updateVisibility(id: UUID, isVisible: Bool)

    func updateAlpha(id: UUID, alpha: Int, isStartHandleDragging: Bool)
}
