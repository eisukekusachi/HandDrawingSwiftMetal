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

    @Published private(set) var drawingTool: DrawingTool

    private let storage: CoreDataStorage<DrawingToolEntity>

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

        // Save to Core Data when the properties are updated
        Publishers.Merge3(
            drawingTool.$brushDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$eraserDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$type.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(saveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.save(self.drawingTool) }
        }
        .store(in: &cancellables)
    }

    var id: UUID {
        drawingTool.id
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

    func update(type: DrawingToolType, brushDiameter: Int, eraserDiameter: Int) {
        drawingTool.setDrawingTool(type)
        drawingTool.setBrushDiameter(brushDiameter)
        drawingTool.setEraserDiameter(eraserDiameter)
    }

    func setDrawingTool(_ type: DrawingToolType) {
        drawingTool.setDrawingTool(type)
    }

    func setBrushDiameter(_ diameter: Int) {
        drawingTool.setBrushDiameter(diameter)
    }

    func setEraserDiameter(_ diameter: Int) {
        drawingTool.setEraserDiameter(diameter)
    }
}

extension CoreDataDrawingToolStorage {
    func update(_ entity: DrawingToolEntity) {

        drawingTool.setId(entity.id ?? UUID())

        setDrawingTool(.init(rawValue: Int(entity.type)))
        setBrushDiameter(Int(entity.brushDiameter))
        setEraserDiameter(Int(entity.eraserDiameter))
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
        self.drawingTool.setDrawingTool(.init(rawValue: result.type))
        self.drawingTool.setBrushDiameter(result.brushDiameter)
        self.drawingTool.setEraserDiameter(result.eraserDiameter)
    }

    func fetch() throws -> DrawingToolEntity? {
        try storage.fetch()
    }
}

private extension CoreDataDrawingToolStorage {
    func save(_ target: DrawingTool) async {
        guard let context = self.storage.context else { return }

        let brushDiameter: Int = target.brushDiameter
        let eraserDiameter: Int = target.eraserDiameter
        let type: Int = target.type.rawValue
        let id: UUID = target.id

        let request = self.storage.fetchRequest()

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? DrawingToolEntity(context: context)

                let currentId = entity.id
                let currentBrushDiameter = Int(entity.brushDiameter)
                let currentEraserDiameter = Int(entity.eraserDiameter)
                let currentType = Int(entity.type)

                // Return if no changes
                guard
                    currentId != id || currentBrushDiameter != brushDiameter || currentEraserDiameter != eraserDiameter || currentType != type
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
