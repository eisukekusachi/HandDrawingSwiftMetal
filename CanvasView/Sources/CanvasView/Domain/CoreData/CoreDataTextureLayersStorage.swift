//
//  CoreDataTextureLayersStorage.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/15.
//

import Combine
import UIKit

@preconcurrency import CoreData

/// Color palette managed by Core Data
@MainActor
public final class CoreDataTextureLayersStorage: TextureLayersProtocol, ObservableObject {

    private var textureLayers: TextureLayers

    /// Emits when a canvas update is requested
    public var canvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        textureLayers.canvasUpdateRequestedPublisher
    }

    /// Emits when a full canvas update is requested
    public var fullCanvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        textureLayers.fullCanvasUpdateRequestedPublisher
    }

    /// Emits whenever `layers` change
    public var layersPublisher: AnyPublisher<[TextureLayerItem], Never> {
        textureLayers.layersPublisher
    }

    /// Emits whenever `selectedLayerId` change
    public var selectedLayerIdPublisher: AnyPublisher<UUID?, Never> {
        textureLayers.selectedLayerIdPublisher
    }

    public var selectedLayer: TextureLayerItem? {
        textureLayers.selectedLayer
    }

    public var selectedIndex: Int? {
        textureLayers.selectedIndex
    }

    public var layers: [TextureLayerItem] {
        textureLayers.layers
    }

    public var layerCount: Int {
        textureLayers.layerCount
    }

    public var textureSize: CGSize {
        textureLayers.textureSize
    }

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: TextureLayers
    ) {
        self.textureLayers = textureLayers

        // Propagate changes from children to the parent
        textureLayers.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    public func initialize(
        configuration: ResolvedTextureLayserArrayConfiguration,
        textureRepository: TextureRepository? = nil,
        undoStack: UndoStack? = nil
    ) async {
        await textureLayers.initialize(
            configuration: configuration,
            textureRepository: textureRepository,
            undoStack: undoStack
        )
    }

    public func layer(_ layerId: UUID) -> TextureLayerItem? {
        textureLayers.layer(layerId)
    }
    
    public func selectLayer(id: UUID) {
        textureLayers.selectLayer(id: id)
    }
    
    public func addLayer(layer: TextureLayerItem, texture: (any MTLTexture)?, at index: Int) async throws {
        try await textureLayers.addLayer(layer: layer, texture: texture, at: index)
    }
    
    public func removeLayer(layerIndexToDelete index: Int) async throws {
        try await textureLayers.removeLayer(layerIndexToDelete: index)
    }
    
    public func moveLayer(indices: MoveLayerIndices) {
        textureLayers.moveLayer(indices: indices)
    }
    
    public func updateTitle(id: UUID, title: String) {
        textureLayers.updateTitle(id: id, title: title)
    }
    
    public func updateVisibility(id: UUID, isVisible: Bool) {
        textureLayers.updateVisibility(id: id, isVisible: isVisible)
    }
    
    public func updateAlpha(id: UUID, alpha: Int, isStartHandleDragging: Bool) {
        textureLayers.updateAlpha(id: id, alpha: alpha, isStartHandleDragging: isStartHandleDragging)
    }

    public func updateThumbnail(_ identifiedTexture: IdentifiedTexture) {
        textureLayers.updateThumbnail(identifiedTexture)
    }
}
