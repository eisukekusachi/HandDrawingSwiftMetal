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
}

extension CoreDataTextureLayers {
    public func fetch() throws -> TextureLayerArrayStorageEntity? {
        try storage.fetch()
    }
}

private extension CoreDataTextureLayers {
    func save() async {
        guard
            let selectedLayerId = selectedLayer?.id,
            layers.count != 0,
            textureSize != .zero
        else { return }

        // Convert it to Sendable
        let layers = layers.map { TextureLayerModel(item: $0) }

        let context = self.storage.context
        let request = self.storage.fetchRequest()

        let textureSize = self.textureSize

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
