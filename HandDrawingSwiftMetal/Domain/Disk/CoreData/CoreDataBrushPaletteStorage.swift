//
//  Created by Eisuke Kusachi
//

import UIKit

@preconcurrency import CoreData

/// Core Data read/write for brush palette.
@MainActor
final class CoreDataBrushPaletteStorage {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() throws -> BrushPaletteEntity? {
        try CoreDataRootEntityStore.fetch(for: BrushPaletteEntity.self, in: context)
    }

    func clearAll() throws {
        try CoreDataRootEntityStore.clearAll(for: BrushPaletteEntity.self, in: context)
    }

    func save(from palette: BrushPalette) async {
        guard let request = CoreDataRootEntityStore.fetchRequest(for: BrushPaletteEntity.self, in: context) else {
            return
        }

        let id: UUID = palette.id
        let index = palette.selectedIndex
        let hexes = palette.items.map { $0.color.hex() }

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? BrushPaletteEntity(context: context)

                let currentId = entity.id
                let currentIndex = Int(entity.index)
                let currentHexes: [String] = (entity.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap {
                    $0.hex
                } ?? []

                guard
                    currentId != id ||
                    currentIndex != index ||
                    currentHexes != hexes
                else { return }

                if currentId != id {
                    entity.id = id
                }

                if currentIndex != index {
                    entity.index = Int16(index)
                }

                if currentHexes != hexes {
                    let currentArrayEntity = (entity.paletteColorGroup?.array as? [PaletteColorEntity]) ?? []

                    if currentArrayEntity.count == hexes.count {
                        for (i, hex) in hexes.enumerated() where currentArrayEntity[i].hex != hex {
                            currentArrayEntity[i].hex = hex
                        }
                        entity.paletteColorGroup = NSOrderedSet(array: currentArrayEntity)

                    } else {
                        currentArrayEntity.forEach {
                            context.delete($0)
                        }
                        let newCurrentArrayEntity = hexes.map { hex -> PaletteColorEntity in
                            let entity = PaletteColorEntity(context: context)
                            entity.hex = hex
                            return entity
                        }
                        entity.paletteColorGroup = NSOrderedSet(array: newCurrentArrayEntity)
                    }
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
