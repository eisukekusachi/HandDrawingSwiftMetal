//
//  CoreDataEraserPaletteStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import CanvasView
import Combine
import UIKit

@preconcurrency import CoreData

/// Alpha palette managed by Core Data
@MainActor
final class CoreDataEraserPaletteStorage {

    private var palette: EraserPalette

    private let storage: CoreDataStorage<EraserPaletteEntity>

    private var cancellables = Set<AnyCancellable>()

    init(palette: EraserPalette, context: NSManagedObjectContext) {
        self.palette = palette
        self.storage = .init(context: context)

        // Save to Core Data when the properties are updated
        Publishers.Merge(
            palette.$index.map { _ in () }.eraseToAnyPublisher(),
            palette.$alphas.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(saveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.save(self.palette) }
        }
        .store(in: &cancellables)
    }
}

extension CoreDataEraserPaletteStorage {

    func fetch() throws -> EraserPaletteEntity? {
        try storage.fetch()
    }

    func update(_ entity: EraserPaletteEntity) {

        palette.setId(entity.id ?? UUID())

        // Load alphas from Core Data
        let alphas: [Int] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap {
            Int($0.alpha)
        } ?? []
        let index = max(0, min(Int(entity.index), alphas.count - 1))

        palette.update(
            alphas: alphas,
            index: index
        )
    }

    func update(directoryURL: URL) throws {
        // Do nothing if an error occurs, since nothing can be done
        guard
            let result = try? EraserPaletteArchiveModel(in: directoryURL)
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
            index: result.index
        )
    }
}

private extension CoreDataEraserPaletteStorage {
    func save(_ target: EraserPalette) async {
        guard
            let context = self.storage.context,
            let request = self.storage.fetchRequest()
        else { return }

        let id = target.id
        let index = target.index
        let alphas = target.alphas

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? EraserPaletteEntity(context: context)

                let currentId = entity.id
                let currentIndex = Int(entity.index)
                let currentAlphas: [Int] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap {
                    Int($0.alpha)
                } ?? []

                // Return if no changes
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
                // Do nothing because nothing can be done
                Logger.error(error)
            }
        }
    }
}
