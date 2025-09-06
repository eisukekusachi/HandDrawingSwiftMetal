//
//  CoreDataBrushPaletteStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import CanvasView
import Combine
import CoreData
import UIKit

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
        palette.$index.sink { [weak self] _ in
            Task { await self?.storage.save(palette) }
        }
        .store(in: &cancellables)

        // Save to Core Data when a color is updated
        palette.$colors.sink { [weak self] _ in
            Task { await self?.storage.save(palette) }
        }
        .store(in: &cancellables)

        Task {
            // Load colors from Core Data
            if let entity = try await storage.load() {
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

        private let uniqueName: String
        private let entityName: String = "BrushPaletteEntity"
        private let relationshipKey: String = "paletteColorGroup"
        private let context: NSManagedObjectContext

        public init(
            uniqueName: String = "default",
            context: NSManagedObjectContext
        ) {
            self.uniqueName = uniqueName
            self.context = context
        }

        public func load() async throws -> (index: Int, hexColors: [String])? {
            try await context.perform {
                guard let palette = try self.fetch() else { return nil }
                return (
                    index: Int(palette.index),
                    hexColors: (palette.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap { $0.hex } ?? []
                )
            }
        }

        func save(_ brushPalette: BrushPalette) async {
            do {
                try await saveData(
                    index: brushPalette.index,
                    hexColors: brushPalette.colors.map { $0.hex() }
                )
            } catch {
                // Do nothing because nothing can be done
                Logger.error(error)
            }
        }

        private func saveData(index: Int, hexColors: [String]) async throws {
            try await context.perform {
                let coreDataPalette = try self.fetch() ?? BrushPaletteEntity(context: self.context)

                let currentIndex = Int(coreDataPalette.index)
                let currentHex: [String] = (coreDataPalette.paletteColorGroup?.array as? [PaletteColorEntity])?
                    .compactMap { $0.hex } ?? []

                if currentIndex == index, currentHex == hexColors {
                    return
                }

                coreDataPalette.name = self.uniqueName

                if currentIndex != index {
                    coreDataPalette.index = Int16(index)
                }

                if currentHex != hexColors {
                    var children = (coreDataPalette.paletteColorGroup?.array as? [PaletteColorEntity]) ?? []

                    if children.count == hexColors.count {
                        for (i, hex) in hexColors.enumerated() where children[i].hex != hex {
                            children[i].hex = hex
                        }
                        coreDataPalette.paletteColorGroup = NSOrderedSet(array: children)
                    } else {
                        children.forEach { self.context.delete($0) }
                        let newChildren = hexColors.map { hex -> PaletteColorEntity in
                            let entity = PaletteColorEntity(context: self.context)
                            entity.hex = hex
                            return entity
                        }
                        coreDataPalette.paletteColorGroup = NSOrderedSet(array: newChildren)
                    }
                }

                if self.context.hasChanges {
                    try self.context.save()
                }
            }
        }

        private func fetch() throws -> BrushPaletteEntity? {
            let request: NSFetchRequest<BrushPaletteEntity> = BrushPaletteEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", uniqueName)
            request.fetchLimit = 1
            request.returnsObjectsAsFaults = false
            return try context.fetch(request).first
        }
    }
}
