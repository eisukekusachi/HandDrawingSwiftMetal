//
//  Created by Eisuke Kusachi
//

import Combine
import Core
import CoreGraphics
@preconcurrency import CoreData
import MetalKit
import Testing
import TextureLayerView

@testable import HandDrawingSwiftMetal

@MainActor
struct HandDrawingViewModelTests {

    private typealias Subject = HandDrawingViewModel

    @MainActor
    struct ShowError {

        @Test
        func `When the error is an unsaved-drawing error, it publishes a toast`() {
            let subject = Subject(dependencies: HandDrawingViewModelTests.dependencies())
            var toasts: [ToastMessage] = []
            var alertMessages: [String] = []
            let toastSubscription = subject.requestingShowToast.sink { toasts.append($0) }
            let alertSubscription = subject.requestingShowAlert.sink { alertMessages.append($0) }
            defer {
                _ = toastSubscription
                _ = alertSubscription
            }

            let persistenceError = TextureLayerCanvasDrawingPersistence.saveInProgressError
            subject.showError(persistenceError)

            #expect(toasts.count == 1)
            #expect(toasts[0].title == persistenceError.localizedFailureReason)
            #expect(alertMessages.isEmpty)
        }

        @Test
        func `When the error is a generic NSError, it publishes an alert message`() {
            let subject = Subject(dependencies: HandDrawingViewModelTests.dependencies())
            var toasts: [ToastMessage] = []
            var alertMessages: [String] = []
            let toastSubscription = subject.requestingShowToast.sink { toasts.append($0) }
            let alertSubscription = subject.requestingShowAlert.sink { alertMessages.append($0) }
            defer {
                _ = toastSubscription
                _ = alertSubscription
            }

            subject.showError(NSError(title: "Error", message: "Something failed"))

            #expect(toasts.isEmpty)
            #expect(alertMessages == ["Something failed"])
        }
    }

    @MainActor
    struct SetupTextureLayers {

        private let layer0: TextureLayerModel = .generate(title: "layer0")
        private let layer1: TextureLayerModel = .generate(title: "layer1")

        @Test
        func `When metadata and pixel files are available, it restores layers from Core Data`() async throws {
            let (savedTextureSize, fallbackTextureSize) = (TestUtils.randomSize(), TestUtils.randomSize())
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()
            try makeTextureLayerArrayEntityInCoreData(
                context: textureLayersCoreDataStorage.viewContext,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: HandDrawingViewModelTests.dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.setupTextureLayers(
                fallbackTextureSize: fallbackTextureSize,
                device: device,
                commandQueue: commandQueue
            )

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
        func `On first launch, it initializes layers with the fallback texture size`() async throws {
            let fallbackTextureSize = TestUtils.randomSize()
            let textureRepository = TextureRepositoryStub()
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: HandDrawingViewModelTests.dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.setupTextureLayers(
                fallbackTextureSize: fallbackTextureSize,
                device: device,
                commandQueue: commandQueue
            )

            // Use fallback size, make one blank layer: layer metadata not used.
            #expect(size == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.isEmpty)
        }

        @Test
        func `When the saved layer list is empty, it initializes with the fallback texture size`() async throws {
            let (savedTextureSize, fallbackTextureSize) = (TestUtils.randomSize(), TestUtils.randomSize())
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()
            try makeTextureLayerArrayEntityInCoreData(
                context: textureLayersCoreDataStorage.viewContext,
                layers: [],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: HandDrawingViewModelTests.dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.setupTextureLayers(
                fallbackTextureSize: fallbackTextureSize,
                device: device,
                commandQueue: commandQueue
            )

            #expect(size == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.count == 1)
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.first?.ids.isEmpty == true)
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.first?.textureSize == savedTextureSize)
        }

        @Test
        func `When pixel files are invalid, it installs a blank layer`() async throws {
            let (savedTextureSize, fallbackTextureSize) = (TestUtils.randomSize(), TestUtils.randomSize())
            let textureLayersCoreDataStorage = makeInMemoryCoreDataStorage()
            try makeTextureLayerArrayEntityInCoreData(
                context: textureLayersCoreDataStorage.viewContext,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()
            textureRepository.validateTextureFilesInLocalDirectoryError = NSError(domain: "error", code: 1)
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: HandDrawingViewModelTests.dependencies(
                    localTextureFileRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.setupTextureLayers(
                fallbackTextureSize: fallbackTextureSize,
                device: device,
                commandQueue: commandQueue
            )

            // After failed restore, use fallback size, make one new layer: layer metadata not used.
            #expect(size == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            #expect(subject.undoableTextureLayers.layerModels.map(\.id) != [layer0.id, layer1.id])
            #expect(textureRepository.validateTextureFilesInLocalDirectoryCalls.count == 1)
        }
    }
}

extension HandDrawingViewModelTests {

    /// Test-only `HandDrawingViewDependencies` using in-memory Core Data stacks (no SQLite).
    fileprivate static func dependencies(
        localTextureFileRepository: MTLTextureDataRepositoryProtocol = TextureRepositoryStub(),
        textureLayersCoreDataStorage: CoreDataStorage? = nil
    ) -> HandDrawingViewDependencies {
        .init(
            localTextureFileRepository: localTextureFileRepository,
            projectCoreDataStorage: CoreDataStorage(
                inMemory: "ProjectStorage",
                bundle: Bundle(for: CoreDataProjectStorage.self)
            ),
            textureLayersCoreDataStorage: textureLayersCoreDataStorage ?? CoreDataStorage(
                inMemory: "TextureLayerStorage",
                bundle: Bundle(for: CoreDataTextureLayerStorage.self)
            ),
            drawingToolCoreDataStorage: CoreDataStorage(
                inMemory: "DrawingToolStorage",
                bundle: Bundle(for: CoreDataDrawingToolStorage.self)
            )
        )
    }
}

extension HandDrawingViewModelTests.SetupTextureLayers {

    private func makeMetal() throws -> (MTLDevice, MTLCommandQueue) {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        return (device, commandQueue)
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