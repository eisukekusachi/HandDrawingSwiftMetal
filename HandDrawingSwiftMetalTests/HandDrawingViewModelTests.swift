//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import MetalKit
import Testing

@testable import HandDrawingSwiftMetal

@MainActor
struct HandDrawingViewModelTests {

    private typealias Subject = HandDrawingViewModel

    @MainActor
    struct LoadTexturesFromDocuments {

        private let savedTextureSize = CGSize(width: 320, height: 240)
        private let fallbackTextureSize = CGSize(width: 512, height: 512)

        private let layer0: TextureLayerModel = .generate(title: "layer0")
        private let layer1: TextureLayerModel = .generate(title: "layer1")

        @Test
        func `When Core Data has no layer metadata, it installs a blank layer`() async throws {
            let textureRepository = TextureRepositoryStub()
            let coreDataStub = CoreDataStorageStub<TextureLayerArrayEntity>()
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: .init(
                    textureDataRepository: textureRepository,
                    textureLayerStorage: CoreDataTextureLayerStorage(storage: coreDataStub)
                )
            )

            let size = try await subject.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )

            // No Core Data metadata, so the method returns the fallback canvas size.
            #expect(size == fallbackTextureSize)
            // installBlankLayer applies the same fallback size to the layer state.
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            // Starts with one newly created empty layer.
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            // Nothing to restore from documents when metadata is missing.
            #expect(textureRepository.restoreTexturesCalls.isEmpty)
            // Stale-metadata cleanup is not triggered.
            #expect(coreDataStub.clearAllCallCount == 0)
        }

        @Test
        func `When metadata and pixel files are available, it restores layers from Core Data`() async throws {
            let context = try TestUtils.makeInMemoryTextureLayerContext()
            let rootEntity = TestUtils.makeTextureLayerArrayEntity(
                context: context,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()
            let coreDataStub = CoreDataStorageStub<TextureLayerArrayEntity>()
            coreDataStub.fetchedEntity = rootEntity
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: .init(
                    textureDataRepository: textureRepository,
                    textureLayerStorage: CoreDataTextureLayerStorage(storage: coreDataStub)
                )
            )

            let size = try await subject.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )

            // Metadata and pixels are valid, so the saved canvas size is returned (not fallback).
            #expect(size == savedTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == savedTextureSize)
            // Layer list is rebuilt from the Core Data snapshot.
            #expect(subject.undoableTextureLayers.layerModels.count == 2)
            #expect(subject.undoableTextureLayers.layerModels.map(\.id) == [layer0.id, layer1.id])
            #expect(subject.undoableTextureLayers.layerModels.map(\.title) == ["layer0", "layer1"])
            // Pixel files are loaded from the documents repository once.
            #expect(textureRepository.restoreTexturesCalls.count == 1)
            #expect(textureRepository.restoreTexturesCalls.first?.ids == [layer0.id, layer1.id])
            #expect(textureRepository.restoreTexturesCalls.first?.textureSize == savedTextureSize)
            // Successful restore does not clear Core Data.
            #expect(coreDataStub.clearAllCallCount == 0)
        }

        @Test
        func `When pixel restore fails, it clears stale Core Data and installs a blank layer`() async throws {
            let context = try TestUtils.makeInMemoryTextureLayerContext()
            let rootEntity = TestUtils.makeTextureLayerArrayEntity(
                context: context,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            let textureRepository = TextureRepositoryStub()
            textureRepository.restoreTexturesError = NSError(domain: "error", code: 1)
            let coreDataStub = CoreDataStorageStub<TextureLayerArrayEntity>()
            coreDataStub.fetchedEntity = rootEntity
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: .init(
                    textureDataRepository: textureRepository,
                    textureLayerStorage: CoreDataTextureLayerStorage(storage: coreDataStub)
                )
            )

            let size = try await subject.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )

            // Restore failed, so the flow falls back to a blank canvas at fallbackTextureSize.
            #expect(size == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            // installBlankLayer replaces stale layers with one new empty layer.
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            #expect(subject.undoableTextureLayers.layerModels.map(\.id) != [layer0.id, layer1.id])
            // Metadata existed, so restore was attempted before falling back.
            #expect(textureRepository.restoreTexturesCalls.count == 1)
            // Stale Core Data metadata is discarded after a failed pixel restore.
            #expect(coreDataStub.clearAllCallCount == 1)
        }
    }
}

extension HandDrawingViewModelTests.LoadTexturesFromDocuments {

    private func makeMetal() throws -> (MTLDevice, MTLCommandQueue) {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        return (device, commandQueue)
    }
}
