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

    @Published private(set) var palette: BrushPalette

    private let storage: CoreDataStorage<BrushPaletteEntity>

    private var cancellables = Set<AnyCancellable>()

    init(palette: BrushPalette, context: NSManagedObjectContext) {
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
            palette.$colors.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(saveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task {
                await self.save(palette)
            }
        }
        .store(in: &cancellables)
    }

    var id: UUID {
        palette.id
    }

    var color: UIColor? {
        palette.color
    }

    func color(at index: Int) -> UIColor? {
        palette.color(at: index)
    }

    func select(_ index: Int) {
        palette.select(index)
    }

    func insert(_ color: UIColor, at index: Int) {
        palette.insert(color, at: index)
    }

    func update(colors: [UIColor], index: Int) {
        palette.update(colors: colors, index: index)
    }

    func update(color: UIColor, at index: Int) {
        palette.update(color: color, at: index)
    }

    func remove(at index: Int) {
        palette.remove(at: index)
    }
}

extension CoreDataBrushPaletteStorage {
    func update(_ entity: BrushPaletteEntity) {

        self.palette.setId(entity.id ?? UUID())

        let colors: [UIColor] = (entity.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap {
            guard let hex = $0.hex else { return nil }
            return UIColor(hex: hex)
        } ?? []
        let index = max(0, min(Int(entity.index), colors.count - 1))

        self.palette.update(
            colors: colors,
            index: index
        )
    }

    func update(directoryURL: URL) throws {
        // Do nothing if an error occurs, since nothing can be done
        guard
            let result = try? BrushPaletteArchiveModel(in: directoryURL)
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
            colors: result.hexColors.map { UIColor(hex: $0) },
            index: result.index
        )
    }

    func fetch() throws -> BrushPaletteEntity? {
        try storage.fetch()
    }
}

private extension CoreDataBrushPaletteStorage {
    func save(_ target: BrushPalette) async {
        guard
            let context = self.storage.context,
            let request = self.storage.fetchRequest()
        else { return }

        let index  = target.index
        let hexes  = target.colors.map { $0.hex() }
        let id: UUID = target.id

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? BrushPaletteEntity(context: context)

                let currentId = entity.id
                let currentIndex = Int(entity.index)
                let currentHexes: [String] = (entity.paletteColorGroup?.array as? [PaletteColorEntity])?.compactMap { $0.hex } ?? []

                // Return if no changes
                guard
                    currentId != id || currentIndex != index || currentHexes != hexes
                else { return }

                if currentId != id {
                    entity.id = id
                }

                if currentIndex != index {
                    entity.index = Int16(index)
                }

                if currentHexes != hexes {
                    let currentArrayEntity = (entity.paletteColorGroup?.array as? [PaletteColorEntity]) ?? []

                    if currentArrayEntity.count == hexes.count {
                        for (i, hex) in hexes.enumerated() where currentArrayEntity[i].hex != hex {
                            currentArrayEntity[i].hex = hex
                        }
                        entity.paletteColorGroup = NSOrderedSet(array: currentArrayEntity)

                    } else {
                        currentArrayEntity.forEach {
                            context.delete($0)
                        }
                        let newCurrentArrayEntity = hexes.map { hex -> PaletteColorEntity in
                            let entity = PaletteColorEntity(context: context)
                            entity.hex = hex
                            return entity
                        }
                        entity.paletteColorGroup = NSOrderedSet(array: newCurrentArrayEntity)
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
