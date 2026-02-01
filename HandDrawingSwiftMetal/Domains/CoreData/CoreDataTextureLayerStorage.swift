//
//  CoreDataTextureLayerStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/02/01.
//

import CanvasView
import Combine
import UIKit

@preconcurrency import CoreData

/// Texture layers managed by Core Data
@MainActor public final class CoreDataTextureLayerStorage: ObservableObject {

    private var textureLayers: any TextureLayersProtocol

    private var storage: CoreDataStorage<TextureLayerArrayEntity>?

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: any TextureLayersProtocol,
        context: NSManagedObjectContext
    ) {
        self.storage = .init(context: context)
        self.textureLayers = textureLayers

        // Save to Core Data when the properties are updated
        Publishers.Merge3(
            self.textureLayers.layersPublisher.map { _ in () }.eraseToAnyPublisher(),
            self.textureLayers.selectedLayerIdPublisher.map { _ in () }.eraseToAnyPublisher(),
            self.textureLayers.textureSizePublisher.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(coreDataSaveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink { [weak self] in
            Task {
                await self?.save()
            }
        }
        .store(in: &cancellables)
    }

    public func fetch() throws -> TextureLayerArrayEntity? {
        try storage?.fetch()
    }

    /// Fetches `textureLayers` data from Core Data, returns nil if an error occurs.
    var textureLayersStateFromCoreDataEntity: TextureLayersState? {
        guard
            let entity = try? storage?.fetch()
        else { return nil }

        let layers: [TextureLayerModel] = entity.textureLayerItems?
            .compactMap { $0 as? TextureLayerEntity }
            .map { layer -> TextureLayerModel in
                .init(
                    id: layer.id ?? LayerId(),
                    title: layer.title ?? "",
                    alpha: Int(layer.alpha),
                    isVisible: layer.isVisible
                )
            } ?? []
        let layerIndex = layers.firstIndex(where: { $0.id == entity.selectedLayerId }) ?? 0
        let textureSize: CGSize = .init(width: Int(entity.textureWidth), height: Int(entity.textureHeight))

        return .init(
            layers: layers,
            layerIndex: layerIndex,
            textureSize: textureSize
        )
    }
}

private extension CoreDataTextureLayerStorage {
    func save() async {
        guard
            let storage,
            let context = storage.context,
            let request = storage.fetchRequest()
        else { return }

        guard
            textureLayers.layers.count != 0,
            textureLayers.textureSize != .zero,
            let selectedLayerId = textureLayers.selectedLayer?.id
        else { return }

        let textureSize = self.textureLayers.textureSize
        let layers = textureLayers.layers.map { TextureLayerModel(item: $0) }

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

