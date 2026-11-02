//
//  Created by Eisuke Kusachi
//

import CanvasView
import CoreGraphics
@preconcurrency import CoreData
import TextureLayerView

@testable import HandDrawingSwiftMetal

/// Shared helpers for unit tests.
enum TestUtils {

    /// Random canvas size within app-supported texture bounds.
    static func randomSize(
        width: ClosedRange<Int> = canvasMinimumTextureLength ... 4096,
        height: ClosedRange<Int> = canvasMinimumTextureLength ... 4096
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
