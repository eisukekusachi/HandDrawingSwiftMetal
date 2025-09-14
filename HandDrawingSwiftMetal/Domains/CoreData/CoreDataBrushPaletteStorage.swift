//
//  CoreDataBrushPaletteStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import CanvasView
import Combine
import UIKit

@preconcurrency import CoreData

/// Color palette managed by Core Data
@MainActor
public final class CoreDataBrushPaletteStorage: BrushPaletteProtocol, ObservableObject {

    @Published var palette: BrushPalette

    private let storage: CoreDataStorage

    private var cancellables = Set<AnyCancellable>()

    init(palette: BrushPalette, context: NSManagedObjectContext) {
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
            palette.$colors.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.storage.save(self.palette) }
        }
        .store(in: &cancellables)

        Task {
            // Load colors from Core Data
            if let entity = try storage.load() {
                let colors = entity.hexColors.compactMap { UIColor(hex: $0) }
                let index = max(0, min(entity.index, colors.count - 1))
                self.palette.update(colors: colors, index: index)
            } else {
                // Save the palette to Core Data
                Task { await storage.save(palette) }
            }
        }
    }

    var color: UIColor? {
        palette.color
    }

    func color(at index: Int) -> UIColor? {
        palette.color(at: index)
    }

    func select(_ index: Int) {
        palette.select(index)
        Task { await storage.save(palette) }
    }

    func insert(_ color: UIColor, at index: Int) {
        palette.insert(color, at: index)
        Task { await storage.save(palette) }
    }

    func update(colors: [UIColor], index: Int) {
        palette.update(colors: colors, index: index)
        Task { await storage.save(palette) }
    }

    func update(color: UIColor, at index: Int) {
        palette.update(color: color, at: index)
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

        private let entityName: String = "BrushPaletteEntity"
        private let relationshipKey: String = "paletteColorGroup"
        private let context: NSManagedObjectContext

        private static func fetchRequest() -> NSFetchRequest<BrushPaletteEntity> {
            let request = BrushPaletteEntity.fetchRequest()
            request.fetchLimit = 1
            request.returnsObjectsAsFaults = false
            return request
        }

        public init(
            context: NSManagedObjectContext
        ) {
            self.context = context
        }

        public func load() throws -> (index: Int, hexColors: [String])? {
            guard let palette = try context.fetch(CoreDataStorage.fetchRequest()).first else { return nil }
            return (
                index: Int(palette.index),
                hexColors: (palette.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap { $0.hex } ?? []
            )
        }

        func save(_ brushPalette: BrushPalette) async {
            let index  = await brushPalette.index
            let hexes  = await brushPalette.colors.map { $0.hex() }

            await self.context.perform { [context] in
                do {
                    let entity = try context.fetch(CoreDataStorage.fetchRequest()).first ?? BrushPaletteEntity(context: context)

                    let currentIndex = Int(entity.index)
                    let currentHexes: [String] = (entity.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap { $0.hex } ?? []

                    // Return if no changes
                    guard currentIndex != index || currentHexes != hexes else {
                        return
                    }

                    if currentIndex != index {
                        entity.index = Int16(index)
                    }

                    if currentHexes != hexes {
                        let children = (entity.paletteColorGroup?.array as? [PaletteColorEntity]) ?? []

                        if children.count == hexes.count {
                            for (i, hex) in hexes.enumerated() where children[i].hex != hex {
                                children[i].hex = hex
                            }
                            entity.paletteColorGroup = NSOrderedSet(array: children)
                        } else {
                            children.forEach { context.delete($0) }
                            let newChildren = hexes.map { hex -> PaletteColorEntity in
                                let entity = PaletteColorEntity(context: context)
                                entity.hex = hex
                                return entity
                            }
                            entity.paletteColorGroup = NSOrderedSet(array: newChildren)
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
