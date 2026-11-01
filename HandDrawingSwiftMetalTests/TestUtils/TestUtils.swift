//
//  Created by Eisuke Kusachi
//

import CoreGraphics
@preconcurrency import CoreData
import TextureLayerView

@testable import HandDrawingSwiftMetal

/// Shared helpers for unit tests.
enum TestUtils {

    @MainActor
    static func makeInMemoryTextureLayerContext() throws -> NSManagedObjectContext {
        let bundle = Bundle(for: CoreDataTextureLayerStorage.self)
        guard
            let modelURL = bundle.url(forResource: "TextureLayerStorage", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw NSError(domain: "TestUtils", code: 1)
        }

        let container = NSPersistentContainer(name: "TextureLayerStorage", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container.viewContext
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
