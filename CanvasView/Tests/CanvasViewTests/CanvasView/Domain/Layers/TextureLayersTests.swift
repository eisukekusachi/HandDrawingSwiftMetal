//
//  TextureLayersTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/21.
//
import Foundation
import Combine
import CoreGraphics
import MetalKit
import Testing

@testable import CanvasView

@MainActor
struct TextureLayersTests {

    // Reusable texture for all tests
    static let texture: MTLTexture = {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeTexture(
                width: 16,
                height: 16,
                with: device
            )
        else {
            fatalError("Failed to create test MTLTexture.")
        }
        return texture
    }()

    @Test("Confirms that adding a layer increases the count and selects the new layer")
    func testAddLayer() async throws {

        let subject = TextureLayers()

        await subject.initialize(
            configuration: .init(textureSize: .init(width: 16, height: 16), layerIndex: 0, layers: []),
            textureRepository: MockTextureRepository()
        )

        #expect(subject.layers.count == 0)
        #expect(subject.selectedLayerId == nil)

        let layer0: TextureLayerItem = .init(id: UUID(), title: "New0", alpha: 255, isVisible: true, thumbnail: nil)

        try await subject.addLayer(
            layer: layer0,
            texture: TextureLayersTests.texture,
            at: 0
        )

        // The layer count increases by one, and the newly added layer is selected
        #expect(subject.layers.count == 1)
        #expect(subject.layers[0].id == layer0.id)
        #expect(subject.selectedLayerId == layer0.id)

        let layer1: TextureLayerItem = .init(id: UUID(), title: "New1", alpha: 255, isVisible: true, thumbnail: nil)

        try await subject.addLayer(
            layer: layer1,
            texture: TextureLayersTests.texture,
            at: 1
        )

        // The layer count increases by one, and the newly added layer is selected
        #expect(subject.layers.count == 2)
        #expect(subject.layers[1].id == layer1.id)
        #expect(subject.selectedLayerId == layer1.id)
    }

    @Test("Confirms that deleting a layer works but at least one layer always remains")
    func testRemoveLayer() async throws {

        let subject = TextureLayers()

        let layer0: TextureLayerModel = .init(id: UUID(), title: "layer0", alpha: 255, isVisible: true)
        let layer1: TextureLayerModel = .init(id: UUID(), title: "layer1", alpha: 255, isVisible: true)

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: [
                    layer0,
                    layer1
                ]
            ),
            textureRepository: MockTextureRepository()
        )

        #expect(subject.layers.count == 2)

        // The layer at the index is deleted
        try await subject.removeLayer(layerIndexToDelete: 1)

        #expect(subject.layers.count == 1)
        #expect(subject.selectedLayerId == layer0.id)

        // At least one layer always remains.
        // If only one layer exists, it cannot be deleted.
        try await subject.removeLayer(layerIndexToDelete: 0)

        #expect(subject.layers.count == 1)
        #expect(subject.selectedLayerId == layer0.id)
    }

    @Test("Confirms that moving a layer changes the order as expected")
    func testMoveLayer() async {

        let subject = TextureLayers()

        let layer2: TextureLayerModel = .init(id: UUID(), title: "layer2", alpha: 255, isVisible: true)
        let layer1: TextureLayerModel = .init(id: UUID(), title: "layer1", alpha: 255, isVisible: true)
        let layer0: TextureLayerModel = .init(id: UUID(), title: "layer0", alpha: 255, isVisible: true)

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: [
                    layer2,
                    layer1,
                    layer0
                ]
            ),
            textureRepository: MockTextureRepository()
        )

        #expect(subject.layers.map { $0.title } == ["layer2", "layer1", "layer0"])

        subject.moveLayer(
            indices: MoveLayerIndices(sourceIndexSet: IndexSet(integer: 2), destinationIndex: 0)
        )

        // In this app, new textures are stacked on top of old ones, so the order is the reverse of a normal array
        #expect(subject.layers.map { $0.title } == ["layer1", "layer0", "layer2"])

        // Since the move operation is implemented as a combination of insert and remove,
        // when moving an item from a smaller index to a larger one,
        // The index must be set to one greater than the expected position.
        subject.moveLayer(
            indices: MoveLayerIndices(sourceIndexSet: IndexSet(integer: 0), destinationIndex: 3)
        )

        #expect(subject.layers.map { $0.title } == ["layer2", "layer1", "layer0"])
    }

    @Test("Confirms that selectLayer updates selectedLayerId to the given layer's id")
    func testSelectLayer() async {

        let subject = TextureLayers()

        let layer2: TextureLayerModel = .init(id: UUID(), title: "layer2", alpha: 255, isVisible: true)
        let layer1: TextureLayerModel = .init(id: UUID(), title: "layer1", alpha: 255, isVisible: true)
        let layer0: TextureLayerModel = .init(id: UUID(), title: "layer0", alpha: 255, isVisible: true)

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: [
                    layer2,
                    layer1,
                    layer0
                ]
            ),
            textureRepository: MockTextureRepository()
        )

        #expect(subject.selectedLayerId == layer2.id)

        subject.selectLayer(layer0.id)

        #expect(subject.selectedLayerId == layer0.id)
    }

    @Test("Confirms that updateTitle updates the layer's title")
    func testUpdateTitle() async {

        let subject = TextureLayers()

        let layer: TextureLayerModel = .init(id: UUID(), title: "oldLayer", alpha: 255, isVisible: true)

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: [
                    layer
                ]
            ),
            textureRepository: MockTextureRepository()
        )
        #expect(subject.layers.first?.title == "oldLayer")

        subject.updateTitle(layer.id, title: "newLayer")

        #expect(subject.layers.first?.title == "newLayer")
    }

    @Test("Confirms that updateAlpha updates the layer's alpha")
    func testUpdateAlpha() async {

        let subject = TextureLayers()

        let layer: TextureLayerModel = .init(id: UUID(), title: "oldLayer", alpha: 255, isVisible: true)

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: [
                    layer
                ]
            ),
            textureRepository: MockTextureRepository()
        )
        #expect(subject.layers.first?.alpha == 255)

        subject.updateAlpha(layer.id, alpha: 100)

        #expect(subject.layers.first?.alpha == 100)
    }

    @Test("Confirms that updateVisibility updates the layer's visibility")
    func testUpdateVisibility() async {

        let subject = TextureLayers()

        let layer: TextureLayerModel = .init(id: UUID(), title: "oldLayer", alpha: 255, isVisible: true)

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: [
                    layer
                ]
            ),
            textureRepository: MockTextureRepository()
        )
        #expect(subject.layers.first?.isVisible == true)

        subject.updateVisibility(layer.id, isVisible: false)

        #expect(subject.layers.first?.isVisible == false)
    }
}
