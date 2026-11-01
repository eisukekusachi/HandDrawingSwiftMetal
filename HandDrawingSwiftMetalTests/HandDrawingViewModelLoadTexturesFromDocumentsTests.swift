//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import MetalKit
import Testing
import TextureLayerView
@testable import HandDrawingSwiftMetal

@MainActor
struct HandDrawingViewModelLoadTexturesFromDocumentsTests {

    let fallbackSize = CGSize(width: 100, height: 200)

    @Test
    func installsBlankLayerWhenNoSavedSnapshot() async throws {
        let repository = TextureRepositoryStub()
        let snapshotReader = TextureLayersSnapshotReaderStub()
        let viewModel = makeViewModel(
            repository: repository,
            snapshotReader: snapshotReader
        )

        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())

        let size = try await viewModel.loadTexturesFromDocuments(
            device: device,
            fallbackTextureSize: fallbackSize,
            commandQueue: commandQueue
        )

        #expect(size == fallbackSize)
        #expect(repository.initializeTextureCallCount == 1)
        #expect(repository.restoreTexturesCallCount == 0)
        #expect(viewModel.undoableTextureLayers.layers.count == 1)
    }

    @Test
    func restoresLayersWhenSnapshotAndDocumentsMatch() async throws {
        let layer = TextureLayerModel.generate(title: "layer0")
        let snapshot = TextureLayersSnapshot(
            layers: [layer],
            layerIndex: 0,
            textureSize: CGSize(width: 300, height: 400)
        )
        let repository = TextureRepositoryStub()
        let snapshotReader = TextureLayersSnapshotReaderStub(snapshot: snapshot)
        let viewModel = makeViewModel(
            repository: repository,
            snapshotReader: snapshotReader
        )

        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())

        let size = try await viewModel.loadTexturesFromDocuments(
            device: device,
            fallbackTextureSize: fallbackSize,
            commandQueue: commandQueue
        )

        #expect(size == snapshot.textureSize)
        #expect(repository.restoreTexturesCallCount == 1)
        #expect(repository.initializeTextureCallCount == 0)
        #expect(viewModel.undoableTextureLayers.layers.map(\.id) == [layer.id])
    }

    @Test
    func clearsSavedMetadataAndInstallsBlankWhenRestoreFails() async throws {
        let layer = TextureLayerModel.generate(title: "layer0")
        let snapshot = TextureLayersSnapshot(
            layers: [layer],
            layerIndex: 0,
            textureSize: CGSize(width: 300, height: 400)
        )
        let repository = TextureRepositoryStub()
        repository.restoreTexturesError = NSError(
            domain: "HandDrawingViewModelLoadTexturesFromDocumentsTests",
            code: 1
        )
        let snapshotReader = TextureLayersSnapshotReaderStub(snapshot: snapshot)
        let viewModel = makeViewModel(
            repository: repository,
            snapshotReader: snapshotReader
        )

        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())

        let size = try await viewModel.loadTexturesFromDocuments(
            device: device,
            fallbackTextureSize: fallbackSize,
            commandQueue: commandQueue
        )

        #expect(size == fallbackSize)
        #expect(snapshotReader.clearSavedLayersCallCount == 1)
        #expect(repository.initializeTextureCallCount == 1)
        #expect(viewModel.undoableTextureLayers.layers.count == 1)
    }

    @Test
    func propagatesErrorWhenBlankLayerInitializationFails() async throws {
        let repository = TextureRepositoryStub()
        repository.initializeTextureError = NSError(
            domain: "HandDrawingViewModelLoadTexturesFromDocumentsTests",
            code: 2
        )
        let viewModel = makeViewModel(
            repository: repository,
            snapshotReader: TextureLayersSnapshotReaderStub()
        )

        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())

        await #expect(throws: NSError.self) {
            try await viewModel.loadTexturesFromDocuments(
                device: device,
                fallbackTextureSize: fallbackSize,
                commandQueue: commandQueue
            )
        }
    }

    private func makeViewModel(
        repository: TextureRepositoryStub,
        snapshotReader: TextureLayersSnapshotReaderStub
    ) -> HandDrawingViewModel {
        HandDrawingViewModel(
            dependencies: .init(
                documentsTextureDataRepository: repository,
                textureLayerStorage: { _ in snapshotReader }
            )
        )
    }
}
