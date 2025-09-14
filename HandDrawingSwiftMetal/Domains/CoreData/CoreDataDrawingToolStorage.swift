//
//  CoreDataDrawingToolStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/09/14.
//

import CanvasView
import Combine
import UIKit

@preconcurrency import CoreData

/// DrawingTool managed by Core Data
@MainActor
final class CoreDataDrawingToolStorage: DrawingToolProtocol, ObservableObject {

    @Published var drawingTool: DrawingTool

    private let storage: CoreDataStorage

    private var cancellables = Set<AnyCancellable>()

    init(
        drawingTool: DrawingTool,
        context: NSManagedObjectContext
    ) {
        self.drawingTool = drawingTool
        self.storage = .init(context: context)

        // Propagate changes from children to the parent
        drawingTool.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Save to Core Data when the index is updated
        Publishers.Merge3(
            drawingTool.$brushDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$eraserDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$type.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.storage.save(self.drawingTool) }
        }
        .store(in: &cancellables)

        Task {
            // Load alphas from Core Data
            if let entity = try await storage.load() {
                update(entity)
            } else {
                // Save the palette to Core Data
                Task { await storage.save(drawingTool) }
            }
        }
    }

    var type: DrawingToolType {
        drawingTool.type
    }

    var brushDiameter: Int {
        drawingTool.brushDiameter
    }

    var eraserDiameter: Int {
        drawingTool.eraserDiameter
    }

    func reset() {
        drawingTool.reset()
        Task { await storage.save(drawingTool) }
    }

    func setDrawingTool(_ type: DrawingToolType) {
        drawingTool.setDrawingTool(type)
        Task { await storage.save(drawingTool) }
    }

    func setBrushDiameter(_ diameter: Int) {
        drawingTool.setBrushDiameter(diameter)
        Task { await storage.save(drawingTool) }
    }

    func setEraserDiameter(_ diameter: Int) {
        drawingTool.setEraserDiameter(diameter)
        Task { await storage.save(drawingTool) }
    }

    func update(_ entity: DrawingToolEntity) {
        setDrawingTool(.init(rawValue: Int(entity.type)))
        setBrushDiameter(Int(entity.brushDiameter))
        setEraserDiameter(Int(entity.eraserDiameter))
    }
}

private extension CoreDataDrawingToolStorage {
    final class CoreDataStorage {

        private let entityName: String = "DrawingToolEntity"
        private let context: NSManagedObjectContext

        private static func fetchRequest() -> NSFetchRequest<DrawingToolEntity> {
            let request = DrawingToolEntity.fetchRequest()
            request.fetchLimit = 1
            request.returnsObjectsAsFaults = false
            return request
        }

        public init(
            context: NSManagedObjectContext
        ) {
            self.context = context
        }

        public func load() async throws -> (DrawingToolEntity)? {
            try context.fetch(CoreDataStorage.fetchRequest()).first
        }

        func save(_ drawingTool: DrawingTool) async {
            let brushDiameter: Int = await drawingTool.brushDiameter
            let eraserDiameter: Int = await drawingTool.eraserDiameter
            let type: Int = await drawingTool.type.rawValue

            await self.context.perform { [context] in
                do {
                    let entity = try context.fetch(CoreDataStorage.fetchRequest()).first ?? DrawingToolEntity(context: context)

                    let currentBrushDiameter = Int(entity.brushDiameter)
                    let currentEraserDiameter = Int(entity.eraserDiameter)
                    let currentType = Int(entity.type)

                    // Return if no changes
                    guard
                        currentBrushDiameter != brushDiameter ||
                        currentEraserDiameter != eraserDiameter ||
                        currentType != type
                    else { return }

                    if currentBrushDiameter != brushDiameter {
                        entity.brushDiameter = Int16(brushDiameter)
                    }

                    if currentEraserDiameter != eraserDiameter {
                        entity.eraserDiameter = Int16(eraserDiameter)
                    }

                    if currentType != type {
                        entity.type = Int16(type)
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    // Do nothing because nothing can be done
                    Logger.error(error)
                }
            }
        }
    }
}
