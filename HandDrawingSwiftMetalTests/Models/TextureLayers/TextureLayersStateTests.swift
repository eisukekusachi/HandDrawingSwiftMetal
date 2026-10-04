//
//  Created by Eisuke Kusachi
//

import Core
import CoreGraphics
import MetalKit
import Testing
import TextureLayerView
import UIKit
@testable import HandDrawingSwiftMetal

@MainActor
struct TextureLayersStateTests {

    typealias Subject = TextureLayersState

    let textureSize: CGSize = .init(width: 123, height: 456)

    let layer0: TextureLayerModel = .generate(title: "layer0", alpha: 10, isVisible: true)
    let layer1: TextureLayerModel = .generate(title: "layer1", alpha: 20, isVisible: true)
    let layer2: TextureLayerModel = .generate(title: "layer2", alpha: 30, isVisible: false)

    @Test
    func `Confirms setLayers keeps the given layers and selection`() async throws {
        let subject: Subject = .init()

        subject.setLayers(
            [layer0, layer1, layer2],
            textureSize: textureSize,
            selectedIndex: 1
        )

        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id, layer2.id])
        #expect(subject.selectedLayerIndex == 1)
        #expect(subject.selectedLayer?.id == layer1.id)
        #expect(subject.textureSize == textureSize)
    }

    @Test
    func `Confirms selectedIndex is clamped to the last layer`() async throws {
        let subject: Subject = .init()

        subject.setLayers(
            [layer0, layer1],
            textureSize: textureSize,
            selectedIndex: 3
        )

        #expect(subject.layers.count == 2)
        #expect(subject.selectedLayerIndex == 1)
        #expect(subject.selectedLayer?.id == layer1.id)
    }

    @Test
    func `Confirms a negative selectedIndex is clamped to 0`() async throws {
        let subject: Subject = .init()

        subject.setLayers(
            [layer0, layer1, layer2],
            textureSize: textureSize,
            selectedIndex: -1
        )

        #expect(subject.layers.count == 3)
        #expect(subject.selectedLayerIndex == 0)
        #expect(subject.selectedLayer?.id == layer0.id)
    }

    @Test
    func `Confirms setLayers restores a snapshot`() async throws {
        let subject: Subject = .init()
        let snapshot = TextureLayersSnapshot(
            layers: [layer0, layer1, layer2],
            layerIndex: 2,
            textureSize: textureSize
        )

        subject.setLayers(snapshot)

        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id, layer2.id])
        #expect(subject.selectedLayer?.id == layer2.id)
        #expect(subject.selectedLayerSnapshot?.id == layer2.id)
        #expect(subject.snapshot.layerIndex == 2)
        #expect(subject.snapshot.textureSize == textureSize)
    }

    @Test
    func `Confirms an empty list clears the selection`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0], textureSize: textureSize)

        subject.setLayers([], textureSize: textureSize)

        #expect(subject.layers.isEmpty)
        #expect(subject.selectedLayer == nil)
        #expect(subject.selectedLayerIndex == nil)
        #expect(subject.snapshot.layerIndex == 0)
    }

    @Test
    func `Confirms inserting a layer selects it and keeps its thumbnail`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0], textureSize: textureSize)

        subject.insertLayer(layer: layer1, thumbnail: UIImage(), at: 0)

        #expect(subject.layers.map(\.id) == [layer1.id, layer0.id])
        #expect(subject.selectedLayer?.id == layer1.id)
        #expect(subject.layers[0].thumbnail != nil)
    }

    @Test
    func `Confirms setLayers clears thumbnails`() async throws {
        let subject: Subject = .init()
        subject.insertLayer(layer: layer0, thumbnail: UIImage(), at: 0)

        subject.setLayers([layer0], textureSize: textureSize)

        #expect(subject.layers[0].thumbnail == nil)
    }

    @Test
    func `Confirms deleting the first layer selects the following layer`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1, layer2], textureSize: textureSize)

        let removed = subject.removeLayer(layerIndexToDelete: 0)

        #expect(removed)
        #expect(subject.layers.map(\.id) == [layer1.id, layer2.id])
        #expect(subject.selectedLayer?.id == layer1.id)
    }

    @Test
    func `Confirms deleting a later layer selects the previous layer`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1, layer2], textureSize: textureSize, selectedIndex: 2)

        let removed = subject.removeLayer(layerIndexToDelete: 2)

        #expect(removed)
        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id])
        #expect(subject.selectedLayer?.id == layer1.id)
    }

    @Test
    func `Confirms removing an out-of-bounds index does nothing`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        let removed = subject.removeLayer(layerIndexToDelete: 2)

        #expect(removed == false)
        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id])
        #expect(subject.selectedLayerIndex == 0)
    }

    @Test
    func `Confirms the last layer cannot be removed`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0], textureSize: textureSize)

        let removed = subject.removeLayer(layerIndexToDelete: 0)

        #expect(removed == false)
        #expect(subject.layers.map(\.id) == [layer0.id])
        #expect(subject.selectedLayerIndex == 0)
    }

    @Test
    func `Confirms renameLayer updates the title`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0], textureSize: textureSize)

        try subject.renameLayer(id: layer0.id, title: "renamed")
        // An unknown id does not add a layer
        try subject.renameLayer(id: LayerId(), title: "missing")

        #expect(subject.layer(layer0.id)?.title == "renamed")
        #expect(subject.layers.count == 1)
    }

    @Test
    func `Confirms selectLayer, setVisibility, and setAlpha update the layer`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        try subject.selectLayer(id: layer1.id)
        try subject.setVisibility(id: layer1.id, isVisible: false)
        subject.setAlpha(id: layer1.id, alpha: 40)

        #expect(subject.selectedLayer?.id == layer1.id)
        #expect(subject.layer(layer1.id)?.isVisible == false)
        #expect(subject.layer(layer1.id)?.alpha == 40)
        #expect(subject.selectedLayerSnapshot?.alpha == 40)
        #expect(subject.layerSnapshots.map(\.id) == [layer0.id, layer1.id])
    }

    @Test
    func `Confirms moveLayers reorders the layers`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1, layer2], textureSize: textureSize)

        // The list is shown in reverse, so UI index 0 is the last layer.
        try subject.moveLayers(from: IndexSet(integer: 0), to: 3)

        #expect(subject.layers.map(\.id) == [layer2.id, layer0.id, layer1.id])
    }

    @Test
    func `Confirms updateLayerThumbnail stores an image only for an existing layer`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0], textureSize: textureSize)
        let thumbnail = UIImage()

        subject.updateLayerThumbnail(layer0.id, thumbnail: thumbnail)
        subject.updateLayerThumbnail(LayerId(), thumbnail: thumbnail)
        subject.updateLayerThumbnail(layer0.id, thumbnail: nil)

        #expect(subject.layers[0].thumbnail != nil)
        #expect(subject.layers.count == 1)
    }

    @Test
    func `Confirms removeLayer by id does nothing when the canvas is missing`() async throws {
        let repository = TextureRepositoryStub()
        let subject: Subject = .init(repository: repository)
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        let removed = try await subject.removeLayer(id: layer0.id)

        #expect(removed == false)
        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id])
        #expect(repository.removedIds.isEmpty)
    }

    @Test
    func `Confirms addLayer throws when required data is missing`() async throws {
        let subject: Subject = .init()

        await #expect(throws: NSError.self) {
            try await subject.addLayer()
        }
    }
}

final class TextureRepositoryStub: TextureLayersDocumentsRepositoryProtocol, @unchecked Sendable {

    var removedIds: [UUID] = []

    let workingDirectoryURL: URL = FileManager.default.temporaryDirectory

    func initializeStorage(
        id: UUID,
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {}

    func restoreStorageFromWorkingDirectory(
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws {}

    func restoreStorage(
        from sourceFolderURL: URL,
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> Bool { false }

    func duplicatedTexture(
        _ id: UUID,
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw NSError(domain: "TextureRepositoryStub", code: 1)
        }
        return texture
    }

    func duplicatedTextures(
        _ ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> [(UUID, MTLTexture)] { [] }

    func addTextureData(data: Data, id: UUID) async throws -> Bool { true }

    func removeTexture(_ id: UUID) throws -> Bool {
        removedIds.append(id)
        return true
    }

    func removeAll() throws {}

    func copyTexture(id: UUID, to: URL) async throws -> Bool { false }

    func writeDataToDisk(id: UUID, data: Data) async throws {}
}
