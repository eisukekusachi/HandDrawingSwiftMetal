//
//  CoreDataTextureLayers.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/15.
//

import Combine
import UIKit

@preconcurrency import CoreData

/// The debounce duration before performing a save operation.
public let saveDebounceMilliseconds: Int = 500

/// Texture layers managed by Core Data
@MainActor
public final class CoreDataTextureLayers: TextureLayers {

    private let storage: CoreDataStorage<TextureLayerArrayStorageEntity>

    private var cancellables = Set<AnyCancellable>()

    public init(
        canvasRenderer: CanvasRenderer?,
        context: NSManagedObjectContext
    ) {
        self.storage = .init(context: context)

        super.init(canvasRenderer: canvasRenderer)

        // Save to Core Data when the properties are updated
        Publishers.Merge3(
            self.layersPublisher.map { _ in () }.eraseToAnyPublisher(),
            self.selectedLayerIdPublisher.map { _ in () }.eraseToAnyPublisher(),
            self.textureSizePublisher.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(saveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink { [weak self] in
            Task {
                await self?.save()
            }
        }
        .store(in: &cancellables)
    }

    public func fetch() throws -> TextureLayerArrayStorageEntity? {
        try storage.fetch()
    }
}

private extension CoreDataTextureLayers {
    func save() async {
        guard
            layers.count != 0,
            textureSize != .zero,
            let selectedLayerId = selectedLayer?.id
        else { return }

        let newTextureSize = self.textureSize
        let newSelectedLayerId = selectedLayerId
        let newLayers = layers.map { TextureLayerModel(item: $0) }

        let context = self.storage.context
        let request = self.storage.fetchRequest()
        request.fetchLimit = 1

        await context.perform { [context] in
            do {
                var newTextureLayerArray: [TextureLayerStorageEntity] = []

                // Fetch the stored entity if found, otherwise create a new one.
                let storageEntity: TextureLayerArrayStorageEntity = try context.fetch(request).first ??
                TextureLayerArrayStorageEntity(context: context)

                let storageTextureLayerEntities = (storageEntity.textureLayerArray as? Set<TextureLayerStorageEntity>) ?? []

                let storageEntityDictionary: Dictionary<UUID, TextureLayerStorageEntity> = .init(
                    uniqueKeysWithValues: storageTextureLayerEntities.compactMap {
                        guard let id = $0.id else { return nil }
                        return (id, $0)
                    }
                )
                for (index, newLayer) in newLayers.enumerated() {
                    // Reuse the existing entity if found, otherwise create a new one.
                    let entity = storageEntityDictionary[newLayer.id] ??
                    TextureLayerStorageEntity(context: context)

                    if entity.id != newLayer.id { entity.id = newLayer.id }
                    if entity.title != newLayer.title { entity.title = newLayer.title }
                    if entity.alpha != Int16(newLayer.alpha) { entity.alpha = Int16(newLayer.alpha) }
                    if entity.isVisible != newLayer.isVisible { entity.isVisible = newLayer.isVisible }
                    if entity.orderIndex != Int16(index) { entity.orderIndex = Int16(index) }

                    newTextureLayerArray.append(entity)
                }
                let newTextureLayerIds = newTextureLayerArray.compactMap({ $0.id })

                // Remove entities that no longer exist
                storageTextureLayerEntities
                    .filter { entity in
                        guard let entityId = entity.id else { return false }
                        return !newTextureLayerIds.contains(entityId)
                    }
                    .forEach { entity in
                        context.delete(entity)
                    }

                // Update entities only if values have actually changed
                if storageTextureLayerEntities.compactMap({ $0.id }) != newTextureLayerIds {
                    storageEntity.textureLayerArray = NSSet(array: newTextureLayerArray)
                }
                if storageEntity.textureWidth != Int16(newTextureSize.width) {
                    storageEntity.textureWidth = Int16(newTextureSize.width)
                }
                if storageEntity.textureHeight != Int16(newTextureSize.height) {
                    storageEntity.textureHeight = Int16(newTextureSize.height)
                }
                if storageEntity.selectedLayerId != newSelectedLayerId {
                    storageEntity.selectedLayerId = newSelectedLayerId
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
