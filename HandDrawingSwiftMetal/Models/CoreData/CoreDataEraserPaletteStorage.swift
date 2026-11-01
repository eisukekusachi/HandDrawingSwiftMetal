//
//  Created by Eisuke Kusachi
//

import CanvasView
import UIKit

@preconcurrency import CoreData

/// Alpha palette managed by Core Data
@MainActor
final class CoreDataEraserPaletteStorage {

    private let storage: any CoreDataStorageProtocol<EraserPaletteEntity>

    convenience init(context: NSManagedObjectContext) {
        self.init(storage: CoreDataStorage(context: context))
    }

    init(storage: any CoreDataStorageProtocol<EraserPaletteEntity>) {
        self.storage = storage
    }
}

extension CoreDataEraserPaletteStorage {

    func fetch() throws -> EraserPaletteEntity? {
        try storage.fetch()
    }

    func update(_ entity: EraserPaletteEntity, palette: EraserPalette) {
        palette.setId(entity.id ?? UUID())

        let alphas: [Int] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap {
            Int($0.alpha)
        } ?? []
        let index = max(0, min(Int(entity.index), alphas.count - 1))

        palette.update(
            alphas: alphas,
            selectedIndex: index
        )
    }

    func update(directoryURL: URL, palette: EraserPalette) throws {
        guard
            let result = try? EraserPaletteSnapshot(in: directoryURL)
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
            alphas: result.alphas,
            selectedIndex: result.index
        )
    }

    func save(from palette: EraserPalette) async {
        guard
            let context = storage.context,
            let request = storage.fetchRequest()
        else { return }

        let id = palette.id
        let index = palette.selectedIndex
        let alphas = palette.items.map(\.alpha)

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? EraserPaletteEntity(context: context)

                let currentId = entity.id
                let currentIndex = Int(entity.index)
                let currentAlphas: [Int] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap {
                    Int($0.alpha)
                } ?? []

                guard
                    currentId != id ||
                    currentIndex != index ||
                    currentAlphas != alphas
                else { return }

                if currentId != id {
                    entity.id = id
                }

                if currentIndex != index {
                    entity.index = Int16(index)
                }

                if currentAlphas != alphas {
                    let currentArrayEntity = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity]) ?? []

                    if currentArrayEntity.count == alphas.count {
                        for (i, alpha) in alphas.enumerated() where currentArrayEntity[i].alpha != alpha {
                            currentArrayEntity[i].alpha = Int16(alpha)
                        }
                        entity.paletteAlphaGroup = NSOrderedSet(array: currentArrayEntity)

                    } else {
                        currentArrayEntity.forEach {
                            context.delete($0)
                        }
                        let newCurrentArrayEntity = alphas.map { alpha -> PaletteAlphaEntity in
                            let entity = PaletteAlphaEntity(context: context)
                            entity.alpha = Int16(alpha)
                            return entity
                        }
                        entity.paletteAlphaGroup = NSOrderedSet(array: newCurrentArrayEntity)
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
