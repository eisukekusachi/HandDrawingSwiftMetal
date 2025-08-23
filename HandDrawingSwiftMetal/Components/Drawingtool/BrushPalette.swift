//
//  BrushPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import Combine
import CoreData
import UIKit

public protocol BrushPaletteStorage {
    func load() async throws -> (index: Int, hexColors: [String])?
    func save(index: Int, hexColors: [String]) async throws
}

public final class BrushPalette: ObservableObject {

    @Published private(set) var colors: [UIColor] = []
    @Published private(set) var currentIndex: Int = 0

    private let initialColors: [UIColor]

    private let storage: BrushPaletteStorage

    public init(
        initialColors: [UIColor] = [UIColor.red.withAlphaComponent(0.5), .purple, .blue],
        storage: BrushPaletteStorage
    ) {
        self.initialColors = initialColors
        self.storage = storage

        Task {
            if let entity = try await storage.load() {
                self.colors = entity.hexColors.compactMap { UIColor(hex: $0) }
                self.currentIndex = max(0, min(entity.index, self.colors.count - 1))
            } else {
                self.colors = self.initialColors
                self.currentIndex = 0
                try await storage.save(
                    index: currentIndex,
                    hexColors: colors.map { $0.hex() }
                )
            }
        }
    }

    public final class CoreDataStorage: BrushPaletteStorage {

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

        public func save(index: Int, hexColors: [String]) async throws {
            try await context.perform {
                let palette = try self.fetch() ?? BrushPaletteEntity(context: self.context)
                palette.name = self.uniqueName
                palette.index = Int16(index)
                palette.paletteColorGroup = NSOrderedSet(
                    array: hexColors.map { hex -> PaletteColorEntity in
                        let entity = PaletteColorEntity(context: self.context)
                        entity.hex = hex
                        return entity
                    }
                )

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

extension BrushPalette {
    public var currentColor: UIColor {
        colors[currentIndex]
    }

    public func color(at index: Int) -> UIColor? {
        colors.indices.contains(index) ? colors[index] : nil
    }

    public func append(_ color: UIColor) async throws {
        colors.append(color)
        try await saveData()
    }

    public func insert(_ color: UIColor, at index: Int) async throws {
        guard (0 ... colors.count).contains(index) else { return }
        colors.insert(color, at: index)
        try await saveData()
    }

    public func update(_ color: UIColor, at index: Int) async throws {
        guard colors.indices.contains(index) else { return }
        colors[index] = color
        try await saveData()
    }

    public func remove(at index: Int) async throws {
        guard colors.indices.contains(index) && colors.count > 1 else { return }
        colors.remove(at: index)
        try await saveData()
    }

    public func removeAll() async throws {
        colors = initialColors
        currentIndex = 0
        try await saveData()
    }

    public func replaceAll(with newColors: [UIColor]) async throws {
        colors = newColors.isEmpty ? initialColors : newColors
        currentIndex = 0
        try await saveData()
    }
}

extension BrushPalette {
    private func saveData() async throws {
        try await storage.save(
            index: currentIndex,
            hexColors: colors.map { $0.hex() }
        )
    }
}
