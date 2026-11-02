//
//  Created by Eisuke Kusachi
//

@preconcurrency import CoreData

/// Core Data read/write for drawing tool settings.
@MainActor
final class CoreDataDrawingToolStorage {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() throws -> DrawingToolEntity? {
        try CoreDataRootEntityStore.fetch(for: DrawingToolEntity.self, in: context)
    }

    func clearAll() throws {
        try CoreDataRootEntityStore.clearAll(for: DrawingToolEntity.self, in: context)
    }

    func save(from drawingTool: DrawingTool) async {
        guard let request = CoreDataRootEntityStore.fetchRequest(for: DrawingToolEntity.self, in: context) else {
            return
        }

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
