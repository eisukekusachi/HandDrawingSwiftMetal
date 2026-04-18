import Testing

@testable import TextureLayerCanvasView

import CanvasView
import TextureLayerView

@preconcurrency import MetalKit

@Suite
struct TextureLayerCanvasViewTests {

    @Test @MainActor
    func duplicateTextureFromDocumentsDirectory_passesTextureSizeAndDevice_andReturnsTexture() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let layerId = LayerId()
        let textureSize = CGSize(width: 64, height: 32)

        let expectedTexture = try #require(Self.makeTexture(size: textureSize, device: device))

        let repository = MockTextureLayersDocumentsRepository()
        repository.duplicatedTextureResult = expectedTexture

        let state = TextureLayersState(
            textureLayers: .init(
                layers: [
                    .init(id: layerId, title: "Layer", alpha: 255, isVisible: true)
                ],
                layerIndex: 0,
                textureSize: textureSize
            )
        )

        let renderer = try #require(MockRenderer(device: device))

        let viewModel = TextureLayerCanvasViewModel(
            textureLayersState: state,
            renderer: renderer,
            dependencies: .init(textureLayersDocumentsRepository: repository)
        )

        let result = await viewModel.duplicateTextureFromDocumentsDirectory(layerId)

        #expect(result != nil)
        #expect(repository.duplicatedTextureCalls.count == 1)
        #expect(repository.duplicatedTextureCalls.first?.id == layerId)
        #expect(repository.duplicatedTextureCalls.first?.textureSize == textureSize)
        #expect(repository.duplicatedTextureCalls.first?.device === device)
        #expect(result === expectedTexture)
    }

    @Test @MainActor
    func duplicateTexturesFromDocumentsDirectory_passesTextureSizeAndDevice_andReturnsTextures() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let id1 = LayerId()
        let id2 = LayerId()
        let textureSize = CGSize(width: 16, height: 16)

        let t1 = try #require(Self.makeTexture(size: textureSize, device: device))
        let t2 = try #require(Self.makeTexture(size: textureSize, device: device))

        let repository = MockTextureLayersDocumentsRepository()
        repository.duplicatedTexturesResult = [(id1, t1), (id2, t2)]

        let state = TextureLayersState(
            textureLayers: .init(
                layers: [
                    .init(id: id1, title: "Layer1", alpha: 255, isVisible: true),
                    .init(id: id2, title: "Layer2", alpha: 255, isVisible: true)
                ],
                layerIndex: 0,
                textureSize: textureSize
            )
        )

        let renderer = try #require(MockRenderer(device: device))
        let viewModel = TextureLayerCanvasViewModel(
            textureLayersState: state,
            renderer: renderer,
            dependencies: .init(textureLayersDocumentsRepository: repository)
        )

        let result = await viewModel.duplicateTexturesFromDocumentsDirectory([id1, id2])

        #expect(result.count == 2)
        #expect(repository.duplicatedTexturesCalls.count == 1)
        #expect(repository.duplicatedTexturesCalls.first?.ids == [id1, id2])
        #expect(repository.duplicatedTexturesCalls.first?.textureSize == textureSize)
        #expect(repository.duplicatedTexturesCalls.first?.device === device)
        #expect(result[0].1 === t1)
        #expect(result[1].1 === t2)
    }

    @Test @MainActor
    func saveTextureToDocumentsDirectory_forwardsIdAndDataToRepository() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let layerId = LayerId()
        let textureSize = CGSize(width: 8, height: 8)

        let repository = MockTextureLayersDocumentsRepository()

        let state = TextureLayersState(
            textureLayers: .init(
                layers: [
                    .init(id: layerId, title: "Layer", alpha: 255, isVisible: true)
                ],
                layerIndex: 0,
                textureSize: textureSize
            )
        )

        let renderer = try #require(MockRenderer(device: device))
        let viewModel = TextureLayerCanvasViewModel(
            textureLayersState: state,
            renderer: renderer,
            dependencies: .init(textureLayersDocumentsRepository: repository)
        )

        let data = Data([0x01, 0x02, 0x03])
        try await viewModel.saveTextureToDocumentsDirectory(layerId: layerId, textureData: data)

        #expect(repository.writeCalls.count == 1)
        #expect(repository.writeCalls.first?.id == layerId)
        #expect(repository.writeCalls.first?.data == data)
    }
}

extension TextureLayerCanvasViewTests {
    static func makeTexture(size: CGSize, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: max(Int(size.width), 1),
            height: max(Int(size.height), 1),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }
}
