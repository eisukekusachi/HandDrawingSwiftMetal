//
//  Created by Eisuke Kusachi
//

@preconcurrency import CoreData

/// Alpha palette managed by Core Data
@MainActor
final class CoreDataEraserPaletteStorage: CoreDataStorage<EraserPaletteEntity> {

    init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    init(storage: any CoreDataStorageProtocol<EraserPaletteEntity>) {
        super.init(injecting: storage)
    }
}

extension CoreDataEraserPaletteStorage {

    func save(from palette: EraserPalette) async {
        guard
            let context = resolvedContext(),
            let request = resolvedFetchRequest()
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
