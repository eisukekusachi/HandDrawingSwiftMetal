//
//  CanvasStateStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import CoreData
import UIKit

final class CanvasStateStorage {

    var needsErrorDialogDisplayPublisher: AnyPublisher<Error, Never> {
        needsErrorDialogDisplaySubject.eraseToAnyPublisher()
    }
    var needsToastDisplayPublisher: AnyPublisher<String, Never> {
        needsToastDisplaySubject.eraseToAnyPublisher()
    }

    private var canvasState: CanvasState?

    private var canvasStorage: CanvasStorageEntity?

    private let entityName = "CanvasStorage"

    private let needsErrorDialogDisplaySubject = PassthroughSubject<Error, Never>()
    private let needsToastDisplaySubject = PassthroughSubject<String, Never>()

    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("CoreData Load Error: \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private var cancellables = Set<AnyCancellable>()

    func setupStorage(_ canvasState: CanvasState) {
        self.canvasState = canvasState

        do {
            let request = NSFetchRequest<CanvasStorageEntity>(entityName: entityName)
            request.fetchLimit = 1

            if let existing = try context.fetch(request).first {
                loadState(from: existing, into: canvasState)
                canvasStorage = existing

            } else {
                initializeWithNewStorage(canvasState, to: CanvasStorageEntity(context: context))
                try saveState()
            }

            bindState()

        } catch {
            needsErrorDialogDisplaySubject.send(error)
        }
    }


    private func initializeWithNewStorage(_ canvasState: CanvasState, to newStorage: CanvasStorageEntity) {
        let brush = BrushStorageEntity(context: context)
        brush.colorHex = canvasState.drawingToolState.brush.color.hexString()
        brush.diameter = Int16(canvasState.drawingToolState.brush.diameter)

        let eraser = EraserStorageEntity(context: context)
        eraser.alpha = Int16(canvasState.drawingToolState.eraser.alpha)
        eraser.diameter = Int16(canvasState.drawingToolState.eraser.diameter)

        let drawingTool = DrawingToolStorageEntity(context: context)
        drawingTool.brush = brush
        drawingTool.eraser = eraser

        brush.drawingTool = drawingTool
        eraser.drawingTool = drawingTool

        newStorage.projectName = canvasState.projectName

        newStorage.drawingTool?.brush = brush
        newStorage.drawingTool?.eraser = eraser

        newStorage.selectedLayerId = canvasState.selectedLayerId

        for (index, layer) in canvasState.layers.enumerated() {
            let texture = TextureLayerStorageEntity(context: context)
            texture.title = layer.title
            texture.alpha = Int16(layer.alpha)
            texture.orderIndex = Int16(index)
            texture.canvas = newStorage
        }

        canvasStorage = newStorage
    }

    private func loadState(from canvasStorage: CanvasStorageEntity?, into canvasState: CanvasState) {
        guard
            let canvasStorage,
            let projectName = canvasStorage.projectName
        else { return }

        canvasState.projectName = projectName

        if let brush = canvasStorage.drawingTool?.brush,
           let colorHexString = brush.colorHex {
            canvasState.drawingToolState.brush.color = UIColor(hex: colorHexString)
            canvasState.drawingToolState.brush.diameter = Int(brush.diameter)
        }

        if let eraser = canvasStorage.drawingTool?.eraser {
            canvasState.drawingToolState.eraser.alpha = Int(eraser.alpha)
            canvasState.drawingToolState.eraser.diameter = Int(eraser.diameter)
        }

        canvasState.selectedLayerId = canvasStorage.selectedLayerId

        if let layers = canvasStorage.textureLayers as? Set<TextureLayerStorageEntity> {
            canvasState.layers = layers
                .sorted { $0.orderIndex < $1.orderIndex }
                .enumerated()
                .map { index, layer in
                    TextureLayerModel(
                        title: layer.title ?? "",
                        alpha: Int(layer.alpha),
                        isVisible: layer.isVisible
                    )
                }
        }
    }

    private func bindState() {
        guard
            let canvasStorage,
            let brush = canvasStorage.drawingTool?.brush,
            let eraser = canvasStorage.drawingTool?.eraser
        else { return }

        cancellables.removeAll()

        canvasState?.$projectName
            .dropFirst()
            .compactMap { $0 }
            .assign(to: \.projectName, on: canvasStorage)
            .store(in: &cancellables)

        canvasState?.drawingToolState.brush.$color
            .dropFirst()
            .map { $0.hexString() }
            .assign(to: \.colorHex, on: brush)
            .store(in: &cancellables)

        canvasState?.drawingToolState.brush.$diameter
            .dropFirst()
            .map { Int16($0) }
            .assign(to: \.diameter, on: brush)
            .store(in: &cancellables)

        canvasState?.drawingToolState.eraser.$alpha
            .dropFirst()
            .map { Int16($0) }
            .assign(to: \.alpha, on: eraser)
            .store(in: &cancellables)

        canvasState?.drawingToolState.eraser.$diameter
            .dropFirst()
            .map { Int16($0) }
            .assign(to: \.diameter, on: eraser)
            .store(in: &cancellables)

        canvasState?.$selectedLayerId
            .dropFirst()
            .assign(to: \.selectedLayerId, on: canvasStorage)
            .store(in: &cancellables)

        canvasState?.$layers
            .dropFirst()
            .sink { [weak self] layers in
                self?.replaceTextureLayers(with: layers)
            }
            .store(in: &cancellables)
    }

    private func replaceTextureLayers(with layers: [TextureLayerModel]) {
        guard let storage = canvasStorage else { return }

        if let existing = storage.textureLayers as? Set<TextureLayerStorageEntity> {
            existing.forEach(context.delete)
        }
        layers.enumerated().forEach { index, model in
            let newLayer = TextureLayerStorageEntity(context: context)
            newLayer.title = model.title
            newLayer.alpha = Int16(model.alpha)
            newLayer.orderIndex = Int16(index)
            newLayer.canvas = storage
        }
        try? saveState()
    }

}

extension CanvasStateStorage {

    func fetchCanvasState() throws -> CanvasStorageEntity? {
        let request = NSFetchRequest<CanvasStorageEntity>(entityName: entityName)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func saveState() throws {
        guard context.hasChanges else { return }
        try context.save()
    }

}
