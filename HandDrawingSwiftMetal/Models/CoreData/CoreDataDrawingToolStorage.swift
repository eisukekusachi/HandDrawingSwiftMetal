//
//  Created by Eisuke Kusachi
//

@preconcurrency import CoreData

/// DrawingTool managed by Core Data
@MainActor
final class CoreDataDrawingToolStorage {

    private let storage: any CoreDataStorageProtocol<DrawingToolEntity>

    convenience init(context: NSManagedObjectContext) {
        self.init(storage: CoreDataStorage(context: context))
    }

    init(storage: any CoreDataStorageProtocol<DrawingToolEntity>) {
        self.storage = storage
    }
}

extension CoreDataDrawingToolStorage {

    func fetch() throws -> DrawingToolEntity? {
        try storage.fetch()
    }

    func save(from drawingTool: DrawingTool) async {
        guard
            let context = storage.context,
            let request = storage.fetchRequest()
        else { return }

        let id: UUID = drawingTool.id
        let type: Int = drawingTool.type.rawValue
        let brushDiameter: Int = drawingTool.brushDiameter
        let eraserDiameter: Int = drawingTool.eraserDiameter

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? DrawingToolEntity(context: context)

                let currentId = entity.id
                let currentType = Int(entity.type)
                let currentBrushDiameter = Int(entity.brushDiameter)
                let currentEraserDiameter = Int(entity.eraserDiameter)

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
                Logger.error(error)
            }
        }
    }
}
