//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core
import MetalKit
import Testing
import TextureLayerView
@testable import HandDrawingSwiftMetal

@MainActor
struct TextureLayerCanvasDrawingPersistenceTests {

    typealias Subject = TextureLayerCanvasDrawingPersistence

    @Test
    func `throwIfUnsavedDrawing does nothing when activeLayerId is nil`() throws {
        let subject = Subject { _, _, _ in }

        try subject.throwIfUnsavedDrawing()
    }

    @Test
    func `throwIfUnsavedDrawing throws while a debounced save is pending`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        let subject = Subject { _, _, _ in }
        let texture = try #require(
            MTLTextureCreator.makeTexture(
                width: 16,
                height: 16,
                with: device
            )
        )

        subject.saveToStorageWithDebouncing(
            layerId: LayerId(),
            texture: texture,
            device: device,
            commandQueue: commandQueue
        )

        let error = #expect(throws: NSError.self) {
            try subject.throwIfUnsavedDrawing()
        }
        #expect(TextureLayerCanvasDrawingPersistence.isSaveInProgressError(try #require(error)))
    }

    @Test
    func `saveToStorageWithDebouncing clears activeLayerId after a successful save`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        var savedLayerIds: [LayerId] = []
        let subject = Subject { layerId, _, _ in
            savedLayerIds.append(layerId)
        }
        let layerId = LayerId()

        let texture = try #require(
            MTLTextureCreator.makeTexture(
                width: 16,
                height: 16,
                with: device
            )
        )

        subject.saveToStorageWithDebouncing(
            layerId: layerId,
            texture: texture,
            device: device,
            commandQueue: commandQueue
        )
        #expect(subject.activeLayerId == layerId)

        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(savedLayerIds == [layerId])
        // Cleared after saveLayerData succeeds.
        #expect(subject.activeLayerId == nil)
    }

    @Test
    func `saveToStorageWithDebouncing clears activeLayerId when saveLayerData fails`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        struct SaveError: Error {}
        let subject = Subject { _, _, _ in
            throw SaveError()
        }
        let layerId = LayerId()

        let texture = try #require(
            MTLTextureCreator.makeTexture(
                width: 16,
                height: 16,
                with: device
            )
        )

        subject.saveToStorageWithDebouncing(
            layerId: layerId,
            texture: texture,
            device: device,
            commandQueue: commandQueue
        )

        try await Task.sleep(nanoseconds: 600_000_000)

        // Cleared after a failed attempt so layer actions are not left blocked (data may still be only on GPU).
        #expect(subject.activeLayerId == nil)
        try subject.throwIfUnsavedDrawing()
    }
}
