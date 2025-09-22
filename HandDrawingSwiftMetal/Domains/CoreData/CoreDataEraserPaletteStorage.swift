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
public final class CoreDataEraserPaletteStorage: EraserPaletteProtocol, ObservableObject {

    @Published private(set) var palette: EraserPalette

    private let storage: CoreDataStorage<EraserPaletteEntity>

    private var cancellables = Set<AnyCancellable>()

    init(palette: EraserPalette, context: NSManagedObjectContext) {
        self.palette = palette
        self.storage = .init(context: context)

        // Propagate changes from children to the parent
        palette.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Save to Core Data when the properties are updated
        Publishers.Merge(
            palette.$index.map { _ in () }.eraseToAnyPublisher(),
            palette.$alphas.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.save(self.palette) }
        }
        .store(in: &cancellables)
    }

    var id: UUID {
        palette.id
    }

    var alpha: Int? {
        palette.alpha
    }

    func alpha(at index: Int) -> Int? {
        palette.alpha(at: index)
    }

    func select(_ index: Int) {
        palette.select(index)
    }

    func insert(_ alpha: Int, at index: Int) {
        palette.insert(alpha, at: index)
    }

    func update(alphas: [Int], index: Int) {
        palette.update(alphas: alphas, index: index)
    }

    func update(alpha: Int, at index: Int) {
        palette.update(alpha: alpha, at: index)
    }

    func remove(at index: Int) {
        palette.remove(at: index)
    }

    func reset() {
        palette.reset()
    }
}

extension CoreDataEraserPaletteStorage {
    func update(_ entity: EraserPaletteEntity) {

        self.palette.setId(entity.id ?? UUID())

        // Load alphas from Core Data
        let alphas: [Int] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap {
            Int($0.alpha)
        } ?? []
        let index = max(0, min(Int(entity.index), alphas.count - 1))

        self.palette.update(
            alphas: alphas,
            index: index
        )
    }
    func fetch() throws -> EraserPaletteEntity? {
        try storage.fetch()
    }
}

private extension CoreDataEraserPaletteStorage {
    func save(_ target: EraserPalette) async {
        let index  = target.index
        let alphas  = target.alphas
        let id: UUID = target.id

        let context = self.storage.context
        let request = self.storage.fetchRequest()

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? EraserPaletteEntity(context: context)

                let currentId = entity.id
                let currentIndex = Int(entity.index)
                let currentAlphas: [Int] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap { Int($0.alpha) } ?? []

                // Return if no changes
                guard
                    currentId != id || currentIndex != index || currentAlphas != alphas
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
