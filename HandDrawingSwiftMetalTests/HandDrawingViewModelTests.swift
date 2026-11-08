//
//  Created by Eisuke Kusachi
//

import Core
import CoreGraphics
@preconcurrency import CoreData
import Testing
import TextureLayerView

@testable import HandDrawingSwiftMetal

@MainActor
struct HandDrawingViewModelTests {

    private typealias Subject = HandDrawingViewModel

    @MainActor
    struct SetupTextureLayers {

        private let layer0: TextureLayerModel = .generate(title: "layer0")
        private let layer1: TextureLayerModel = .generate(title: "layer1")

        @Test
        func `When metadata and pixel files are available, it restores layers from Core Data`() throws {
            let savedTextureSize = TestUtils.randomSize()
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()
            try makeTextureLayerArrayEntityInCoreData(
                context: textureLayersCoreDataStorage.viewContext,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()

            let subject: Subject = .init(
                dependencies: dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try subject.setupTextureLayers()

            // Use saved size, make two layers: layer metadata used.
            #expect(size == savedTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == savedTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 2)
            #expect(subject.undoableTextureLayers.layerModels.map(\.id) == [layer0.id, layer1.id])
            #expect(subject.undoableTextureLayers.layerModels.map(\.title) == ["layer0", "layer1"])
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.count == 1)
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.first?.ids == [layer0.id, layer1.id])
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.first?.textureSize == savedTextureSize)
        }

        @Test
        func `When Core Data has no layer metadata, it returns nil`() throws {
            let textureRepository = TextureRepositoryStub()
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()

            let subject: Subject = .init(
                dependencies: dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            #expect(try subject.setupTextureLayers() == nil)
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.isEmpty)
        }

        @Test
        func `When pixel files are invalid, it throws`() throws {
            let savedTextureSize = TestUtils.randomSize()
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()
            try makeTextureLayerArrayEntityInCoreData(
                context: textureLayersCoreDataStorage.viewContext,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()
            textureRepository.validateTextureFilesInLocalDirectoryError = NSError(domain: "error", code: 1)

            let subject: Subject = .init(
                dependencies: dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            #expect(throws: (any Error).self) {
                try subject.setupTextureLayers()
            }
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.count == 1)
        }
    }
}

extension HandDrawingViewModelTests.SetupTextureLayers {

    /// Test-only `HandDrawingViewDependencies` using in-memory Core Data stacks (no SQLite).
    private func dependencies(
        localTextureFileRepository: MTLTextureDataRepositoryProtocol,
        textureLayersCoreDataStorage: CoreDataStorage
    ) -> HandDrawingViewDependencies {
        .init(
            localTextureFileRepository: localTextureFileRepository,
            projectCoreDataStorage: CoreDataStorage(
                inMemory: "ProjectStorage",
                bundle: Bundle(for: CoreDataProjectStorage.self)
            ),
            textureLayersCoreDataStorage: textureLayersCoreDataStorage,
            drawingToolCoreDataStorage: CoreDataStorage(
                inMemory: "DrawingToolStorage",
                bundle: Bundle(for: CoreDataDrawingToolStorage.self)
            )
        )
    }

    private func makeInMemoryCoreDataStorage() -> CoreDataStorage {
        CoreDataStorage(
            inMemory: "TextureLayerStorage",
            bundle: Bundle(for: CoreDataTextureLayerStorage.self)
        )
    }

    /// Persists layer metadata in an in-memory Core Data stack for load tests.
    private func makeTextureLayerArrayEntityInCoreData(
        context: NSManagedObjectContext,
        layers: [TextureLayerModel],
        textureSize: CGSize,
        selectedLayerId: LayerId? = nil
    ) throws {
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
        try context.save()
    }
}
