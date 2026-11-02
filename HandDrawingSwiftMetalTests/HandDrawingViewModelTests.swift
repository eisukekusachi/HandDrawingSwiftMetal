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

        private let layer0: TextureLayerModel = .generate(title: "layer0")
        private let layer1: TextureLayerModel = .generate(title: "layer1")

        @Test
        func `When metadata and pixel files are available, it restores layers from Core Data`() async throws {
            let (savedTextureSize, fallbackTextureSize) = (TestUtils.randomSize(), TestUtils.randomSize())
            let textureLayersCoreDataStorage = TestUtils.makeInMemoryTextureLayersCoreDataStorage()
            let context = textureLayersCoreDataStorage.viewContext
            _ = TestUtils.makeTextureLayerArrayEntity(
                context: context,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            try context.save()
            let textureRepository = TextureRepositoryStub()
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: .init(
                    textureDataRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )

            // Use saved size, make two layers: layer metadata used.
            #expect(size == savedTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == savedTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 2)
            #expect(subject.undoableTextureLayers.layerModels.map(\.id) == [layer0.id, layer1.id])
            #expect(subject.undoableTextureLayers.layerModels.map(\.title) == ["layer0", "layer1"])
            #expect(textureRepository.restoreTexturesCalls.count == 1)
            #expect(textureRepository.restoreTexturesCalls.first?.ids == [layer0.id, layer1.id])
            #expect(textureRepository.restoreTexturesCalls.first?.textureSize == savedTextureSize)
        }

        @Test
        func `When Core Data has no layer metadata, it installs a blank layer`() async throws {
            let fallbackTextureSize = TestUtils.randomSize()
            let textureRepository = TextureRepositoryStub()
            let textureLayersCoreDataStorage = TestUtils.makeInMemoryTextureLayersCoreDataStorage()
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: .init(
                    textureDataRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )

            // Use fallback size, make one blank layer: layer metadata not used.
            #expect(size == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            #expect(textureRepository.restoreTexturesCalls.isEmpty)
        }

        @Test
        func `When pixel restore fails, it clears stale Core Data and installs a blank layer`() async throws {
            let (savedTextureSize, fallbackTextureSize) = (TestUtils.randomSize(), TestUtils.randomSize())
            let textureLayersCoreDataStorage = TestUtils.makeInMemoryTextureLayersCoreDataStorage()
            let context = textureLayersCoreDataStorage.viewContext
            _ = TestUtils.makeTextureLayerArrayEntity(
                context: context,
                layers: [layer0, layer1],
                textureSize: savedTextureSize
            )
            try context.save()
            let textureRepository = TextureRepositoryStub()
            textureRepository.restoreTexturesError = NSError(domain: "error", code: 1)
            let (device, commandQueue) = try makeMetal()

            let subject: Subject = .init(
                dependencies: .init(
                    textureDataRepository: textureRepository,
                    textureLayersCoreDataStorage: textureLayersCoreDataStorage
                )
            )

            let size = try await subject.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )

            // After failed pixel restore, use fallback size, make one new layer: layer metadata not used.
            #expect(size == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.textureSize == fallbackTextureSize)
            #expect(subject.undoableTextureLayers.layerModels.count == 1)
            #expect(subject.undoableTextureLayers.layerModels.map(\.id) != [layer0.id, layer1.id])
            #expect(textureRepository.restoreTexturesCalls.count == 1)
            #expect(try subject.dependencies.textureLayerStorage.fetch() == nil)
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
