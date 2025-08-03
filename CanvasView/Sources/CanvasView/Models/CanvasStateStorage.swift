//
//  CanvasStateStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import CoreData
import UIKit

/// A class that binds `CanvasState` and `CoreDataRepository`
final class CanvasStateStorage {

    private(set) var coreDataConfiguration: CanvasConfiguration?

    let alertSubject = PassthroughSubject<NSError, Never>()

    private var coreDataRepository: CoreDataRepository

    private var cancellables = Set<AnyCancellable>()

    init(
        coreDataRepository: CoreDataRepository = DefaultCoreDataRepository(
            entityName: "CanvasStorageEntity",
            persistentContainerName: "CanvasStorage"
        )
    ) {
        self.coreDataRepository = coreDataRepository
    }

    func setupStorage(_ canvasState: CanvasState) {
        do {
            if let storageEntity = try self.coreDataRepository.fetchEntity() as? CanvasStorageEntity {
                self.coreDataConfiguration = .init(entity: storageEntity)

            } else {
                initializeStorageWithCanvasState(
                    canvasState,
                    to: CanvasStorageEntity(context: self.coreDataRepository.context)
                )
            }

            bindCanvasStateToCoreDataEntities(
                canvasState: canvasState,
                coreDataRepository: self.coreDataRepository
            )

        } catch {
            alertSubject.send(error as NSError)
        }
    }

    func saveContext() {
        do {
            try coreDataRepository.saveContext()
        } catch {
            Logger.error(error)
        }
    }
}

extension CanvasStateStorage {

    private func initializeStorageWithCanvasState(_ canvasState: CanvasState, to newStorage: CanvasStorageEntity) {
        do {
            let brush = BrushStorageEntity(context: coreDataRepository.context)
            brush.colorHex = canvasState.brush.color.hexString()
            brush.diameter = Int16(canvasState.brush.diameter)

            let eraser = EraserStorageEntity(context: coreDataRepository.context)
            eraser.alpha = Int16(canvasState.eraser.alpha)
            eraser.diameter = Int16(canvasState.eraser.diameter)

            let drawingTool = DrawingToolStorageEntity(context: coreDataRepository.context)
            drawingTool.brush = brush
            drawingTool.eraser = eraser

            brush.drawingTool = drawingTool
            eraser.drawingTool = drawingTool

            newStorage.projectName = canvasState.projectName

            newStorage.textureWidth = Int16(canvasState.textureSize.width)
            newStorage.textureHeight = Int16(canvasState.textureSize.height)

            newStorage.drawingTool?.brush = brush
            newStorage.drawingTool?.eraser = eraser
            newStorage.drawingTool = drawingTool
            newStorage.selectedLayerId = canvasState.selectedLayerId

            for (index, layer) in canvasState.layers.enumerated() {
                let texture = TextureLayerStorageEntity(context: coreDataRepository.context)
                texture.title = layer.title
                texture.fileName = TextureLayerModel.fileName(id: layer.id)
                texture.alpha = Int16(layer.alpha)
                texture.orderIndex = Int16(index)
                texture.canvas = newStorage
            }

            try coreDataRepository.saveContext()
        }
        catch {
            alertSubject.send(error as NSError)
        }
    }

    private func bindCanvasStateToCoreDataEntities(canvasState: CanvasState?, coreDataRepository: CoreDataRepository) {
        guard
            let canvasStorageEntity = try? coreDataRepository.fetchEntity() as? CanvasStorageEntity,
            let drawingToolStorage = canvasStorageEntity.drawingTool,
            let brushStorage = drawingToolStorage.brush,
            let eraserStorage = drawingToolStorage.eraser
        else { return }

        cancellables.removeAll()

        canvasState?.$projectName
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] result in
                canvasStorageEntity.projectName = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.$textureSize
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] result in
                canvasStorageEntity.textureWidth = Int16(result.width)
                canvasStorageEntity.textureHeight = Int16(result.height)
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.brush.$color
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .map { $0.hexString() }
            .sink { [weak self] result in
                brushStorage.colorHex = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.brush.$diameter
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .map { Int16($0) }
            .sink { [weak self] result in
                brushStorage.diameter = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.eraser.$alpha
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .map { Int16($0) }
            .sink { [weak self] result in
                eraserStorage.alpha = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.eraser.$diameter
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .map { Int16($0) }
            .sink { [weak self] result in
                eraserStorage.diameter = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.$selectedLayerId
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] result in
                canvasStorageEntity.selectedLayerId = result
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)

        canvasState?.$layers
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] result in
                self?.updateAllTextureLayerEntities(result)
                try? self?.coreDataRepository.saveContext()
            }
            .store(in: &cancellables)
    }

    /// Saves all texture layers to Core Data instead of saving only the differences,
    /// assuming the number of layers stays below 100.
    private func updateAllTextureLayerEntities(_ layers: [TextureLayerModel]) {
        guard
            let canvasStorageEntity = try? coreDataRepository.fetchEntity() as? CanvasStorageEntity
        else { return }

        // Deletes all existing data first
        if let existing = canvasStorageEntity.textureLayers as? Set<TextureLayerStorageEntity> {
            existing.forEach(coreDataRepository.context.delete)
        }

        // Saves all data
        layers.enumerated().forEach { index, model in
            let newLayer = TextureLayerStorageEntity(context: coreDataRepository.context)
            newLayer.title = model.title
            newLayer.fileName = TextureLayerModel.fileName(id: model.id)
            newLayer.isVisible = model.isVisible
            newLayer.alpha = Int16(model.alpha)
            newLayer.orderIndex = Int16(index)
            newLayer.canvas = canvasStorageEntity
        }
    }
}
