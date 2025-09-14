//
//  CoreDataCanvasStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import CoreData
import UIKit

/// A class that binds a model and `CoreDataStorage`
final class CoreDataCanvasStorage {

    private(set) var coreDataConfiguration: TextureLayserArrayConfiguration?

    let alertSubject = PassthroughSubject<NSError, Never>()

    private var coreDataStorage: CoreDataStorage

    private var cancellables = Set<AnyCancellable>()

    private var textureLayerArrayRequest: NSFetchRequest<TextureLayerArrayStorageEntity> {
        let request = TextureLayerArrayStorageEntity.fetchRequest()
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        return request
    }

    @MainActor
    init(
        textureLayers: TextureLayers,
        coreDataStorage: CoreDataStorage = DefaultCoreDataStorage(
            name: "CanvasStorage",
            entityName: "TextureLayerArrayStorageEntity",
            type: .swiftPackageManager
        )
    ) {
        self.coreDataStorage = coreDataStorage

        do {
            if let storageEntity = try self.coreDataStorage.context.fetch(textureLayerArrayRequest).first {
                self.coreDataConfiguration = configuration(from: storageEntity)
            } else {
                initializeStorageWithCanvasState(
                    textureLayers,
                    to: TextureLayerArrayStorageEntity(context: self.coreDataStorage.context)
                )
            }

            bindCanvasStateToCoreDataEntities(
                textureLayers: textureLayers,
                coreDataRepository: coreDataStorage
            )

        } catch {
            Logger.error(error)
            alertSubject.send(error as NSError)
        }
    }

    func saveContext() {
        do {
            try coreDataStorage.saveContext()
        } catch {
            Logger.error(error)
        }
    }
}

extension CoreDataCanvasStorage {

    @MainActor
    private func initializeStorageWithCanvasState(_ textureLayers: TextureLayers, to newStorage: TextureLayerArrayStorageEntity) {
        do {
            //newStorage.projectName = canvasState.projectName

            newStorage.textureWidth = Int16(textureLayers.textureSize.width)
            newStorage.textureHeight = Int16(textureLayers.textureSize.height)

            newStorage.selectedLayerId = textureLayers.selectedLayerId

            for (index, layer) in textureLayers.layers.enumerated() {
                let texture = TextureLayerStorageEntity(context: coreDataStorage.context)
                texture.title = layer.title
                texture.fileName = layer.fileName
                texture.alpha = Int16(layer.alpha)
                texture.orderIndex = Int16(index)
                texture.textureLayerArray = newStorage
            }

            try coreDataStorage.saveContext()
        }
        catch {
            Logger.error(error)
            alertSubject.send(error as NSError)
        }
    }

    @MainActor
    private func bindCanvasStateToCoreDataEntities(textureLayers: TextureLayers?, coreDataRepository: CoreDataStorage) {
        guard
            let canvasStorageEntity = try? self.coreDataStorage.context.fetch(textureLayerArrayRequest).first
        else { return }

        cancellables.removeAll()

        /*
        canvasState?.$projectName
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] result in
                canvasStorageEntity.projectName = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)
        */

        textureLayers?.$textureSize
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] result in
                canvasStorageEntity.textureWidth = Int16(result.width)
                canvasStorageEntity.textureHeight = Int16(result.height)
                try? self?.coreDataStorage.saveContext()
            }
            .store(in: &cancellables)

        textureLayers?.selectedLayerIdPublisher
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] result in
                canvasStorageEntity.selectedLayerId = result
                try? self?.coreDataStorage.saveContext()
            }
            .store(in: &cancellables)

        textureLayers?.layersPublisher
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] result in
                self?.updateAllTextureLayerEntities(result.map { .init(item: $0) })
                try? self?.coreDataStorage.saveContext()
            }
            .store(in: &cancellables)
    }

    /// Saves all texture layers to Core Data instead of saving only the differences,
    /// assuming the number of layers stays below 100.
    private func updateAllTextureLayerEntities(_ layers: [TextureLayerModel]) {
        guard
            let canvasStorageEntity = try? self.coreDataStorage.context.fetch(textureLayerArrayRequest).first
        else { return }

        // Deletes all existing data first
        if let existing = canvasStorageEntity.textureLayerArray as? Set<TextureLayerStorageEntity> {
            existing.forEach(coreDataStorage.context.delete)
        }

        // Saves all data
        layers.enumerated().forEach { index, model in
            let newLayer = TextureLayerStorageEntity(context: coreDataStorage.context)
            newLayer.title = model.title
            newLayer.fileName = model.textureName
            newLayer.isVisible = model.isVisible
            newLayer.alpha = Int16(model.alpha)
            newLayer.orderIndex = Int16(index)
            newLayer.textureLayerArray = canvasStorageEntity
        }
    }

    public func configuration(
        from entity: TextureLayerArrayStorageEntity
    ) -> TextureLayserArrayConfiguration {

        let width  = max(0, Int(entity.textureWidth))
        let height = max(0, Int(entity.textureHeight))
        let textureSize = CGSize(width: CGFloat(width), height: CGFloat(height))

        let layerSet = (entity.textureLayerArray as? Set<TextureLayerStorageEntity>) ?? []

        let models: [TextureLayerModel] = layerSet
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { layer in
                TextureLayerModel(
                    fileName: layer.fileName ?? UUID().uuidString,
                    title: layer.title ?? "",
                    alpha: Int(layer.alpha),
                    isVisible: layer.isVisible
                )
            }

        let selectedIndex: Int = {
            guard let selectedId = entity.selectedLayerId else { return 0 }
            return models.firstIndex(where: { $0.id == selectedId }) ?? 0
        }()

        return .init(
            textureSize: textureSize,
            layerIndex: selectedIndex,
            layers: models
        )
    }
}
