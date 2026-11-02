//
//  Created by Eisuke Kusachi
//

import CoreGraphics
@preconcurrency import CoreData
import TextureLayerView

@testable import HandDrawingSwiftMetal

/// Shared helpers for unit tests.
enum TestUtils {

    /// Random canvas size safe for `TextureLayerArrayEntity` (`Int16` width/height).
    static func randomSize(
        width: ClosedRange<Int> = 64...1024,
        height: ClosedRange<Int> = 64...1024
    ) -> CGSize {
        CGSize(
            width: Int.random(in: width),
            height: Int.random(in: height)
        )
    }

    /// In-memory `CoreDataStorage` for layer metadata tests (no SQLite side effects).
    @MainActor
    static func makeInMemoryTextureLayersCoreDataStorage() -> CoreDataStorage {
        CoreDataStorage(
            inMemory: "TextureLayerStorage",
            bundle: Bundle(for: CoreDataTextureLayerStorage.self)
        )
    }

    @MainActor
    static func makeTextureLayerArrayEntity(
        context: NSManagedObjectContext,
        layers: [TextureLayerModel],
        textureSize: CGSize,
        selectedLayerId: LayerId? = nil
    ) -> TextureLayerArrayEntity {
        let root = TextureLayerArrayEntity(context: context)
        root.textureWidth = Int16(textureSize.width)
        root.textureHeight = Int16(textureSize.height)
        root.selectedLayerId = selectedLayerId ?? layers.first?.id

        let layerEntities = layers.map { model -> TextureLayerEntity in
            let entity = TextureLayerEntity(context: context)
            entity.id = model.id
            entity.title = model.title
            entity.alpha = Int16(model.alpha)
            entity.isVisible = model.isVisible
            return entity
        }
        root.textureLayerItems = NSOrderedSet(array: layerEntities)
        return root
    }
}
