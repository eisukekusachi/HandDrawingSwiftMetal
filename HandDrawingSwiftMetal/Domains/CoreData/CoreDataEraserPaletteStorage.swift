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

    @Published var palette: EraserPalette

    private let storage: CoreDataStorage

    private var cancellables = Set<AnyCancellable>()

    init(palette: EraserPalette, context: NSManagedObjectContext) {
        self.palette = palette
        self.storage = .init(context: context)

        // Propagate changes from children to the parent
        palette.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Save to Core Data when the index is updated
        Publishers.Merge(
            palette.$index.map { _ in () }.eraseToAnyPublisher(),
            palette.$alphas.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.storage.save(self.palette) }
        }
        .store(in: &cancellables)

        Task {
            // Load alphas from Core Data
            if let entity = try await storage.load() {
                let alphas = entity.alphas
                let index = max(0, min(entity.index, alphas.count - 1))
                self.palette.update(alphas: alphas, index: index)
            } else {
                // Save the palette to Core Data
                Task { await storage.save(palette) }
            }
        }
    }

    var alpha: Int? {
        palette.alpha
    }

    func alpha(at index: Int) -> Int? {
        palette.alpha(at: index)
    }

    func select(_ index: Int) {
        palette.select(index)
        Task { await storage.save(palette) }
    }

    func insert(_ alpha: Int, at index: Int) {
        palette.insert(alpha, at: index)
        Task { await storage.save(palette) }
    }

    func update(alphas: [Int], index: Int) {
        palette.update(alphas: alphas, index: index)
        Task { await storage.save(palette) }
    }

    func update(alpha: Int, at index: Int) {
        palette.update(alpha: alpha, at: index)
        Task { await storage.save(palette) }
    }

    func remove(at index: Int) {
        palette.remove(at: index)
        Task { await storage.save(palette) }
    }

    func reset() {
        palette.reset()
        Task { await storage.save(palette) }
    }
}

private extension CoreDataEraserPaletteStorage {
    final class CoreDataStorage {

        private let entityName: String = "EraserPaletteEntity"
        private let relationshipKey: String = "paletteAlphaGroup"
        private let context: NSManagedObjectContext

        private static func fetchRequest() -> NSFetchRequest<EraserPaletteEntity> {
            let request = EraserPaletteEntity.fetchRequest()
            request.fetchLimit = 1
            request.returnsObjectsAsFaults = false
            return request
        }

        public init(
            context: NSManagedObjectContext
        ) {
            self.context = context
        }

        public func load() async throws -> (index: Int, alphas: [Int])? {
            guard let entity = try context.fetch(CoreDataStorage.fetchRequest()).first else { return nil }
            return (
                index: Int(entity.index),
                alphas: (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap { Int($0.alpha) } ?? []
            )
        }

        func save(_ eraserPalette: EraserPalette) async {
            let index = await eraserPalette.index
            let alphas = await eraserPalette.alphas

            await self.context.perform { [context] in
                do {
                    let entity = try context.fetch(CoreDataStorage.fetchRequest()).first ?? EraserPaletteEntity(context: context)

                    let currentIndex = Int(entity.index)
                    let currentAlphas16: [Int16] = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap { $0.alpha } ?? []
                    let currentAlphas = currentAlphas16.map { Int($0) }

                    // Return if no changes
                    guard currentIndex != index || currentAlphas != alphas else { return }

                    if currentIndex != index {
                        entity.index = Int16(index)
                    }

                    if currentAlphas != alphas {
                        let children = (entity.paletteAlphaGroup?.array as? [PaletteAlphaEntity]) ?? []

                        if children.count == alphas.count {
                            for (i, alpha) in alphas.enumerated() where children[i].alpha != alpha {
                                children[i].alpha = Int16(alpha)
                            }
                            entity.paletteAlphaGroup = NSOrderedSet(array: children)
                        } else {
                            children.forEach { context.delete($0) }
                            let newChildren = alphas.map { alpha -> PaletteAlphaEntity in
                                let entity = PaletteAlphaEntity(context: context)
                                entity.alpha = Int16(alpha)
                                return entity
                            }
                            entity.paletteAlphaGroup = NSOrderedSet(array: newChildren)
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
}
