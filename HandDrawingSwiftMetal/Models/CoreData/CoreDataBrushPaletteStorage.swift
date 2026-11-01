//
//  Created by Eisuke Kusachi
//

import CanvasView
import UIKit

@preconcurrency import CoreData

/// Color palette managed by Core Data
@MainActor
final class CoreDataBrushPaletteStorage {

    private let storage: any CoreDataStorageProtocol<BrushPaletteEntity>

    convenience init(context: NSManagedObjectContext) {
        self.init(storage: CoreDataStorage(context: context))
    }

    init(storage: any CoreDataStorageProtocol<BrushPaletteEntity>) {
        self.storage = storage
    }
}

extension CoreDataBrushPaletteStorage {

    func fetch() throws -> BrushPaletteEntity? {
        try storage.fetch()
    }

    func update(_ entity: BrushPaletteEntity, palette: BrushPalette) {
        palette.setId(entity.id ?? UUID())

        let colors: [UIColor] = (entity.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap {
            guard let hex = $0.hex else { return nil }
            return UIColor(hex: hex)
        } ?? []
        let index = max(0, min(Int(entity.index), colors.count - 1))

        palette.update(colors: colors, selectedIndex: index)
    }

    func update(directoryURL: URL, palette: BrushPalette) throws {
        guard
            let result = try? BrushPaletteSnapshot(in: directoryURL)
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
        palette.update(
            colors: result.hexColors.map { UIColor(hex: $0) },
            selectedIndex: result.index
        )
    }

    func save(from palette: BrushPalette) async {
        guard
            let context = storage.context,
            let request = storage.fetchRequest()
        else { return }

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
