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
final class CoreDataDrawingToolStorage {

    private let drawingTool: DrawingTool

    private let storage: CoreDataStorage<DrawingToolEntity>

    private var cancellables = Set<AnyCancellable>()

    init(
        drawingTool: DrawingTool,
        context: NSManagedObjectContext
    ) {
        self.drawingTool = drawingTool
        self.storage = .init(context: context)

        // Save to Core Data when the properties are updated
        Publishers.Merge3(
            drawingTool.$brushDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$eraserDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$type.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(coreDataSaveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink {
            Task { [weak self] in
                guard let self else { return }
                await self.save(self.drawingTool)
            }
        }
        .store(in: &cancellables)
    }
}

extension CoreDataDrawingToolStorage {

    func fetch() throws -> DrawingToolEntity? {
        try storage.fetch()
    }

    func update(type: DrawingToolType, brushDiameter: Int, eraserDiameter: Int) {
        drawingTool.type = type
        drawingTool.brushDiameter = brushDiameter
        drawingTool.eraserDiameter = eraserDiameter
    }

    func update(_ entity: DrawingToolEntity) {

        drawingTool.setId(entity.id ?? UUID())

        update(
            type: .init(rawValue: Int(entity.type)),
            brushDiameter: Int(entity.brushDiameter),
            eraserDiameter: Int(entity.eraserDiameter)
        )
    }

    func update(directoryURL: URL) throws {
        // Do nothing if an error occurs, since nothing can be done
        guard
            let result = try? DrawingToolArchiveModel(in: directoryURL)
        else {
            let nsError = NSError(
                domain: String(describing: Self.self),
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to find file in \(directoryURL).",
                    "directoryURL": directoryURL.path
                ]
            )
            Logger.error(nsError)
            throw nsError
        }

        update(
            type: .init(rawValue: result.type),
            brushDiameter: result.brushDiameter,
            eraserDiameter: result.eraserDiameter
        )
    }
}

private extension CoreDataDrawingToolStorage {
    func save(_ target: DrawingTool) async {
        guard
            let context = self.storage.context,
            let request = self.storage.fetchRequest()
        else { return }

        let id: UUID = target.id
        let type: Int = target.type.rawValue
        let brushDiameter: Int = target.brushDiameter
        let eraserDiameter: Int = target.eraserDiameter

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? DrawingToolEntity(context: context)

                let currentId = entity.id
                let currentType = Int(entity.type)
                let currentBrushDiameter = Int(entity.brushDiameter)
                let currentEraserDiameter = Int(entity.eraserDiameter)

                // Return if no changes
                guard
                    currentId != id ||
                    currentType != type ||
                    currentBrushDiameter != brushDiameter ||
                    currentEraserDiameter != eraserDiameter
                else { return }

                if currentId != id {
                    entity.id = id
                }

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
