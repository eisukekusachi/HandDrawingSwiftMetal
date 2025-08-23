//
//  EraserPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import Combine
import CoreData
import UIKit

public protocol EraserPaletteStorage {
    func load() async throws -> (index: Int, alphas: [Int])?
    func save(index: Int, alphas: [Int]) async throws
}

@MainActor
public final class EraserPalette: ObservableObject {

    @Published private(set) var alphas: [Int] = []
    @Published private(set) var currentIndex: Int = 0

    private let initialAlphas: [Int]

    private let storage: EraserPaletteStorage

    public init(
        initialAlphas: [Int] = [255],
        initialIndex: Int = 0,
        storage: EraserPaletteStorage
    ) {
        self.initialAlphas = initialAlphas
        self.storage = storage

        Task {
            if let entity = try await storage.load() {
                self.alphas = entity.alphas.compactMap { $0 }
                self.currentIndex = max(0, min(entity.index, self.alphas.count - 1))
            } else {
                self.alphas = self.initialAlphas
                self.currentIndex = max(0, min(initialIndex, self.alphas.count - 1))

                try await storage.save(
                    index: currentIndex,
                    alphas: alphas.map { $0 }
                )
            }
        }
    }

    public final class CoreDataStorage: EraserPaletteStorage {

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

        public func load() async throws -> (index: Int, alphas: [Int])? {
            try await context.perform {
                guard let palette = try self.fetch() else { return nil }
                return (
                    index: Int(palette.index),
                    alphas: (palette.paletteAlphaGroup?.array as? [PaletteAlphaEntity])?.compactMap { Int($0.alpha) } ?? []
                )
            }
        }

        public func save(index: Int, alphas: [Int]) async throws {
            try await context.perform {
                let palette = try self.fetch() ?? EraserPaletteEntity(context: self.context)
                palette.name = self.uniqueName
                palette.index = Int16(index)
                palette.paletteAlphaGroup = NSOrderedSet(
                    array: alphas.map { alpha -> PaletteAlphaEntity in
                        let entity = PaletteAlphaEntity(context: self.context)
                        entity.alpha = Int16(alpha)
                        return entity
                    }
                )

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

    public var currentAlpha: Int? {
        guard alphas.count < currentIndex else { return nil }
        return alphas[currentIndex]
    }

    public func alpha(at index: Int) -> Int? {
        alphas[index]
    }

    public func select(_ index: Int) {
        currentIndex = index
    }

    public func append(_ alpha: Int) async throws {
        alphas.append(alpha)
        try await saveData()
    }

    public func insert(_ alpha: Int, at index: Int) async throws {
        guard (0 ... alphas.count).contains(index) else { return }
        alphas.insert(alpha, at: index)
        try await saveData()
    }

    public func update(_ alpha: Int, at index: Int) async throws {
        guard alphas.indices.contains(index) else { return }
        alphas[index] = alpha
        try await saveData()
    }

    public func remove(at index: Int) async throws {
        guard alphas.indices.contains(index) && alphas.count > 1 else { return }
        alphas.remove(at: index)
        try await saveData()
    }

    public func removeAll() async throws {
        alphas = initialAlphas
        currentIndex = 0
        try await saveData()
    }

    public func replaceAll(with newAlphas: [Int]) async throws {
        alphas = newAlphas.isEmpty ? initialAlphas : newAlphas
        currentIndex = 0
        try await saveData()
    }

    private func saveData() async throws {
        try await storage.save(
            index: currentIndex,
            alphas: alphas
        )
    }
}
