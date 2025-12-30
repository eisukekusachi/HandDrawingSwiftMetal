//
//  TextureLayersTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/21.
//

import Foundation
import Combine
import CoreGraphics
@preconcurrency import MetalKit
import Testing
import SwiftUI

@testable import CanvasView

@MainActor
struct TextureLayersTests {

    private typealias Subject = TextureLayers

    private let renderer = MockMTLRenderer()

    private let textureLayersDocumentsRepository = MockTextureLayersDocumentsRepository()

    // Reusable texture for all tests
    static let dummyTexture: MTLTexture = {
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

    @Test
    func `Verify that adding a layer increases the count and selects the new layer`() async throws {
        let subject = Subject(renderer: renderer)

        subject.setup(
            repository: textureLayersDocumentsRepository
        )

        let layer1: TextureLayerModel = .init(id: LayerId(), title: "New1", alpha: 255, isVisible: true)
        let layer0: TextureLayerModel = .init(id: LayerId(), title: "New0", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                textureSize: .init(width: 16, height: 16)
            )
        )
        #expect(subject.layers.count == 1)
        #expect(subject.selectedIndex == 0)

        try await subject.addLayer(
            layer: layer0,
            newTexture: TextureLayersTests.dummyTexture,
            at: 0
        )

        // The layer count increases by one, and the newly added layer is selected
        #expect(subject.layers.count == 2)
        #expect(subject.selectedLayer?.id == layer0.id)
        #expect(subject.selectedIndex == 0)

        try await subject.addLayer(
            layer: layer1,
            newTexture: TextureLayersTests.dummyTexture,
            at: 1
        )

        // The layer count increases by one, and the newly added layer is selected
        #expect(subject.layers.count == 3)
        #expect(subject.selectedLayer?.id == layer1.id)
        #expect(subject.selectedIndex == 1)
    }

    @Test
    func `Verify that deleting a layer works but at least one layer always remains`() async throws {
        let subject = Subject(renderer: renderer)

        subject.setup(
            repository: textureLayersDocumentsRepository
        )

        let layer0: TextureLayerModel = .init(id: LayerId(), title: "layer0", alpha: 255, isVisible: true)
        let layer1: TextureLayerModel = .init(id: LayerId(), title: "layer1", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                layers: [
                    layer0,
                    layer1
                ],
                layerIndex: 0,
                textureSize: .init(width: 16, height: 16)
            )
        )

        #expect(subject.layers.count == 2)

        // The layer at the index is deleted
        try await subject.removeLayer(layerIndexToDelete: 1)

        #expect(subject.layers.count == 1)
        #expect(subject.selectedLayer?.id == layer0.id)

        // At least one layer always remains.
        // If only one layer exists, it cannot be deleted.
        try await subject.removeLayer(layerIndexToDelete: 0)

        #expect(subject.layers.count == 1)
        #expect(subject.selectedLayer?.id == layer0.id)
    }

    @Test
    func `Verify that moving a layer changes the order as expected`() async throws {
        let subject = Subject(renderer: renderer)

        let layer2: TextureLayerModel = .init(id: LayerId(), title: "layer2", alpha: 255, isVisible: true)
        let layer1: TextureLayerModel = .init(id: LayerId(), title: "layer1", alpha: 255, isVisible: true)
        let layer0: TextureLayerModel = .init(id: LayerId(), title: "layer0", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                layers: [
                    layer2,
                    layer1,
                    layer0
                ],
                layerIndex: 0,
                textureSize: .init(width: 16, height: 16)
            )
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

    @Test
    func `Verify that selectLayer updates selectedLayerId to the given layer's id`() async throws {
        let subject = Subject(renderer: renderer)

        let layer2: TextureLayerModel = .init(id: LayerId(), title: "layer2", alpha: 255, isVisible: true)
        let layer1: TextureLayerModel = .init(id: LayerId(), title: "layer1", alpha: 255, isVisible: true)
        let layer0: TextureLayerModel = .init(id: LayerId(), title: "layer0", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                layers: [
                    layer2,
                    layer1,
                    layer0
                ],
                layerIndex: 0,
                textureSize: .init(width: 16, height: 16)
            )
        )

        #expect(subject.selectedLayer?.id == layer2.id)

        subject.selectLayer(layer0.id)

        #expect(subject.selectedLayer?.id == layer0.id)
    }

    @Test
    func `Verify that updateTitle updates the layer's title`() async throws {
        let subject = Subject(renderer: renderer)

        let layer: TextureLayerModel = .init(id: LayerId(), title: "oldLayer", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                layers: [
                    layer
                ],
                layerIndex: 0,
                textureSize: .init(width: 16, height: 16)
            )
        )

        #expect(subject.layers.first?.title == "oldLayer")

        subject.updateTitle(layer.id, title: "newLayer")

        #expect(subject.layers.first?.title == "newLayer")
    }

    @Test
    func `Verify that updateAlpha updates the layer's alpha`() async throws {
        let subject = Subject(renderer: renderer)

        let layer: TextureLayerModel = .init(id: LayerId(), title: "oldLayer", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                layers: [
                    layer
                ],
                layerIndex: 0,
                textureSize: .init(width: 16, height: 16)
            )
        )

        #expect(subject.layers.first?.alpha == 255)

        subject.updateAlpha(layer.id, alpha: 100)

        #expect(subject.layers.first?.alpha == 100)
    }

    @Test
    func `Verify that updateVisibility updates the layer's visibility`() async throws {
        let subject = Subject(renderer: renderer)

        let layer: TextureLayerModel = .init(id: LayerId(), title: "oldLayer", alpha: 255, isVisible: true)

        subject.updateSkippingThumbnail(
            textureLayersState: .init(
                layers: [
                    layer
                ],
                layerIndex: 0,
                textureSize: .init(width: 16, height: 16)
            )
        )

        #expect(subject.layers.first?.isVisible == true)

        subject.updateVisibility(layer.id, isVisible: false)

        #expect(subject.layers.first?.isVisible == false)
    }
}
