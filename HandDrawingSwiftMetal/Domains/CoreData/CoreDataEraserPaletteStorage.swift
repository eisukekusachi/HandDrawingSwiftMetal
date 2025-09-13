//
//  CoreDataEraserPaletteStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import CanvasView
import Combine
import CoreData
import UIKit

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
        palette.$index.sink { [weak self] _ in
            Task { await self?.storage.save(palette) }
        }
        .store(in: &cancellables)

        // Save to Core Data when alphas are updated
        palette.$alphas.sink { [weak self] _ in
            Task { await self?.storage.save(palette) }
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

    private final class CoreDataStorage {

        private let uniqueName: String
        private let entityName: String = "EraserPaletteEntity"
        private let relationshipKey: String = "paletteAlphaGroup"
        private let context: NSManagedObjectContext

        public init(
            uniqueName: String = "default",
            context: NSManagedObjectContext
        ) {
            self.uniqueName = uniqueName
            self.context = context
        }

        public func load() async throws -> (index: Int, alphas: [Int])? {
            try await context.perform {
                guard let palette = try self.fetch() else { return nil }
                return (
                    index: Int(palette.index),
                    alphas: (palette.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap { Int($0.alpha) } ?? []
                )
            }
        }

        func save(_ eraserPalette: EraserPalette) async {
            do {
                try await save(
                    index: eraserPalette.index,
                    alphas: eraserPalette.alphas
                )
            } catch {
                // Do nothing because nothing can be done
                Logger.error(error)
            }
        }

        private func save(index: Int, alphas: [Int]) async throws {
            try await context.perform {
                let coreData = try self.fetch() ?? EraserPaletteEntity(context: self.context)

                let currentIndex = Int(coreData.index)
                let currentAlphas16: [Int16] = (coreData.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?
                    .compactMap { $0.alpha } ?? []

                let currentAlphas = currentAlphas16.map { Int($0) }

                if currentIndex == index, currentAlphas == alphas {
                    return
                }

                coreData.name = self.uniqueName

                if currentIndex != index {
                    coreData.index = Int16(index)
                }

                if currentAlphas != alphas {
                    let children = (coreData.paletteAlphaGroup?.array as? [PaletteAlphaEntity]) ?? []

                    if children.count == alphas.count {
                        for (i, alpha) in alphas.enumerated() where children[i].alpha != alpha {
                            children[i].alpha = Int16(alpha)
                        }
                        coreData.paletteAlphaGroup = NSOrderedSet(array: children)
                    } else {
                        children.forEach { self.context.delete($0) }
                        let newChildren = currentAlphas.map { alpha -> PaletteAlphaEntity in
                            let entity = PaletteAlphaEntity(context: self.context)
                            entity.alpha = Int16(alpha)
                            return entity
                        }
                        coreData.paletteAlphaGroup = NSOrderedSet(array: newChildren)
                    }
                }

                if self.context.hasChanges {
                    try self.context.save()
                }
            }
        }

        private func fetch() throws -> EraserPaletteEntity? {
            let request: NSFetchRequest<EraserPaletteEntity> = EraserPaletteEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", uniqueName)
            request.fetchLimit = 1
            request.returnsObjectsAsFaults = false
            return try context.fetch(request).first
        }
    }
}
