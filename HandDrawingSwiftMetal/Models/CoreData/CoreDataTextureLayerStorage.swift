//
//  Created by Eisuke Kusachi
//

import TextureLayerView

@preconcurrency import CoreData

/// Core Data read/write for texture layer metadata (`TextureLayerStorage` model).
@MainActor
final class CoreDataTextureLayerStorage: CoreDataStorage<TextureLayerArrayEntity> {

    init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    init(storage: any CoreDataStorageProtocol<TextureLayerArrayEntity>) {
        super.init(injecting: storage)
    }

    override func clearAll() throws {
        do {
            try super.clearAll()
        } catch {
            Logger.error("Failed to clear Core Data storage: \(error)")
            throw error
        }
    }

    func save(from textureLayers: TextureLayersState) async {
        guard
            let context = resolvedContext(),
            let request = resolvedFetchRequest()
        else { return }

        guard
            textureLayers.layers.count != 0,
            textureLayers.textureSize != .zero,
            let selectedLayerId = textureLayers.selectedLayerModel?.id
        else { return }

        let textureSize = textureLayers.textureSize
        let layers = textureLayers.layerModels

        request.fetchLimit = 1

        await context.perform { [context] in
            do {
                var newTextureLayerItems: [TextureLayerEntity] = []

                // Fetch or create root
                let entity = try context.fetch(request).first ?? TextureLayerArrayEntity(context: context)

                let textureLayerItems: [TextureLayerEntity] = entity.textureLayerItems?
                    .compactMap {
                        $0 as? TextureLayerEntity
                    } ?? []
                let textureLayerDictionary: Dictionary<UUID, TextureLayerEntity> = .init(
                    uniqueKeysWithValues: textureLayerItems.compactMap {
                        guard let id = $0.id else { return nil }
                        return (id, $0)
                    }
                )

                for layer in layers {
                    // Reuse the existing entity if found, otherwise create a new one.
                    let layerEntity = textureLayerDictionary[layer.id] ?? TextureLayerEntity(context: context)

                    if layerEntity.id != layer.id { layerEntity.id = layer.id }
                    if layerEntity.title != layer.title { layerEntity.title = layer.title }
                    if layerEntity.alpha != Int16(layer.alpha) { layerEntity.alpha = Int16(layer.alpha) }
                    if layerEntity.isVisible != layer.isVisible { layerEntity.isVisible = layer.isVisible }

                    newTextureLayerItems.append(layerEntity)
                }
                let newTextureLayerIds = newTextureLayerItems.compactMap({ $0.id })

                // Remove entities that no longer exist
                textureLayerItems
                    .filter { entity in
                        guard let entityId = entity.id else { return false }
                        return !newTextureLayerIds.contains(entityId)
                    }
                    .forEach { entity in
                        context.delete(entity)
                    }

                if entity.textureWidth != Int16(textureSize.width) {
                    entity.textureWidth = Int16(textureSize.width)
                }
                if entity.textureHeight != Int16(textureSize.height) {
                    entity.textureHeight = Int16(textureSize.height)
                }
                if entity.selectedLayerId != selectedLayerId {
                    entity.selectedLayerId = selectedLayerId
                }
                // Update the relationship to persist changes even when only the order has changed
                if textureLayerItems.compactMap({ $0.id }) != newTextureLayerIds {
                    entity.textureLayerItems = NSOrderedSet(array: newTextureLayerItems)
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
