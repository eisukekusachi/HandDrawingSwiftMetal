//
//  CoreDataTextureLayersStorage.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/15.
//

import Combine
import UIKit

@preconcurrency import CoreData

/// Texture layers managed by Core Data
@MainActor
public final class CoreDataTextureLayersStorage: TextureLayersProtocol, ObservableObject {

    @Published private var textureLayers: any TextureLayersProtocol

    private let storage: CoreDataStorage<TextureLayerArrayStorageEntity>

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

    /// Emits whenever `textureSize` change
    public var textureSizePublisher: AnyPublisher<CGSize, Never> {
        textureLayers.textureSizePublisher
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
        textureLayers: any TextureLayersProtocol,
        context: NSManagedObjectContext
    ) {
        self.textureLayers = textureLayers

        self.storage = .init(context: context)

        // Save to Core Data when the properties are updated
        Publishers.Merge3(
            self.textureLayers.layersPublisher.map { _ in () }.eraseToAnyPublisher(),
            self.textureLayers.selectedLayerIdPublisher.map { _ in () }.eraseToAnyPublisher(),
            self.textureLayers.textureSizePublisher.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task {
                await self.save(textureLayers)
            }
        }
        .store(in: &cancellables)
    }

    public func initialize(
        configuration: ResolvedTextureLayerArrayConfiguration,
        textureRepository: TextureRepository? = nil
    ) async {
        await textureLayers.initialize(
            configuration: configuration,
            textureRepository: textureRepository
        )
    }

    public func layer(_ layerId: UUID) -> TextureLayerItem? {
        textureLayers.layer(layerId)
    }

    public func selectLayer(id: UUID) {
        textureLayers.selectLayer(id: id)
    }

    public func addLayer(layer: TextureLayerItem, texture: MTLTexture, at index: Int) async throws {
        try await textureLayers.addLayer(layer: layer, texture: texture, at: index)
    }

    public func removeLayer(layerIndexToDelete index: Int) async throws {
        try await textureLayers.removeLayer(layerIndexToDelete: index)
    }

    public func moveLayer(indices: MoveLayerIndices) {
        textureLayers.moveLayer(indices: indices)
    }

    public func updateLayer(_ layer: TextureLayerItem) {
        textureLayers.updateLayer(layer)
    }

    public func updateThumbnail(id: UUID, texture: MTLTexture) {
        textureLayers.updateThumbnail(id: id, texture: texture)
    }

    public func updateTitle(id: UUID, title: String) {
        textureLayers.updateTitle(id: id, title: title)
    }

    public func updateVisibility(id: UUID, isVisible: Bool) {
        textureLayers.updateVisibility(id: id, isVisible: isVisible)
    }

    public func updateAlpha(id: UUID, alpha: Int) {
        textureLayers.updateAlpha(id: id, alpha: alpha)
    }

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    public func beginAlphaChange() {
        textureLayers.beginAlphaChange()
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    public func endAlphaChange() {
        textureLayers.endAlphaChange()
    }

    public func requestCanvasUpdate() {
        textureLayers.requestCanvasUpdate()
    }

    public func requestFullCanvasUpdate() {
        textureLayers.requestFullCanvasUpdate()
    }

    public func duplicatedTexture(id: UUID) async throws -> IdentifiedTexture? {
        try await textureLayers.duplicatedTexture(id: id)
    }

    /// Adds a texture using UUID
    @discardableResult
    public func addTexture(_ texture: MTLTexture, uuid: UUID) async throws -> IdentifiedTexture {
        try await textureLayers.addTexture(texture, uuid: uuid)
    }

    /// Updates an existing texture for UUID
    @discardableResult
    public func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        try await textureLayers.updateTexture(texture: texture, for: uuid)
    }

    /// Removes a texture with UUID
    @discardableResult
    public func removeTexture(_ uuid: UUID) throws -> UUID {
        try textureLayers.removeTexture(uuid)
    }
}

extension CoreDataTextureLayersStorage {
    public func fetch() throws -> TextureLayerArrayStorageEntity? {
        try storage.fetch()
    }
}

private extension CoreDataTextureLayersStorage {
    func save(_ target: any TextureLayersProtocol) async {

        // Convert it to Sendable
        let layers = target.layers.map { TextureLayerModel(item: $0) }

        let textureSize = target.textureSize
        let selectedLayerId = target.selectedLayer?.id

        let context = self.storage.context
        let request = self.storage.fetchRequest()

        await context.perform { [context] in
            do {
                // Fetch or create root
                let rootEntity = try context.fetch(request).first ?? TextureLayerArrayStorageEntity(context: context)

                var newTextureLayerEntityArray: [TextureLayerStorageEntity] = []

                let currentTextureLayerEntitySet = (rootEntity.textureLayerArray as? Set<TextureLayerStorageEntity>) ?? []

                let currentTextureLayerEntityDictionary = Dictionary<UUID, TextureLayerStorageEntity>(
                    uniqueKeysWithValues: currentTextureLayerEntitySet.compactMap {
                        guard let id = $0.id else { return nil }
                        return (id, $0)
                    }
                )

                // Create new Core Data layer entities based on the layers
                for (index, layer) in layers.enumerated() {
                    if let entity = currentTextureLayerEntityDictionary[layer.id] {
                        if entity.title != layer.title { entity.title = layer.title }
                        if entity.alpha != Int16(layer.alpha) { entity.alpha = Int16(layer.alpha) }
                        if entity.isVisible != layer.isVisible { entity.isVisible = layer.isVisible }
                        if entity.orderIndex != Int16(index) { entity.orderIndex = Int16(index) }
                        newTextureLayerEntityArray.append(entity)
                    } else {
                        let newEntity = TextureLayerStorageEntity(context: context)
                        newEntity.id = layer.id
                        newEntity.title = layer.title
                        newEntity.alpha = Int16(layer.alpha)
                        newEntity.isVisible = layer.isVisible
                        newEntity.orderIndex = Int16(index)
                        newTextureLayerEntityArray.append(newEntity)
                    }
                }

                let currentLayerIdArray = currentTextureLayerEntitySet.compactMap { $0.id }
                let newLayerIdArray = newTextureLayerEntityArray.compactMap { $0.id }
                let newIdSet = Set(newLayerIdArray)

                // Remove any entities that existed before but are no longer present
                for currentEntity in currentTextureLayerEntitySet {
                    if let currentEntityId = currentEntity.id, !newIdSet.contains(currentEntityId) {
                        context.delete(currentEntity)
                    }
                }

                // Update entities only if values have actually changed
                if rootEntity.textureWidth != Int16(textureSize.width) {
                    rootEntity.textureWidth = Int16(textureSize.width)
                }
                if rootEntity.textureHeight != Int16(textureSize.height) {
                    rootEntity.textureHeight = Int16(textureSize.height)
                }
                if rootEntity.selectedLayerId != selectedLayerId {
                    rootEntity.selectedLayerId = selectedLayerId
                }

                if currentLayerIdArray != newLayerIdArray {
                    rootEntity.textureLayerArray = NSSet(array: newTextureLayerEntityArray)
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                Logger.error(error)
            }
        }
    }
}
