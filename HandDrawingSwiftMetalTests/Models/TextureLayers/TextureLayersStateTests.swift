//
//  Created by Eisuke Kusachi
//

import CanvasView
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

        try subject.setLayers(
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
    func `Confirms setLayers restores a snapshot`() async throws {
        let subject: Subject = .init()
        let snapshot = TextureLayersSnapshot(
            layers: [layer0, layer1, layer2],
            layerIndex: 2,
            textureSize: textureSize
        )

        try subject.setLayers(snapshot)

        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id, layer2.id])
        #expect(subject.selectedLayerModel?.id == layer2.id)
        #expect(subject.selectedLayer?.id == layer2.id)
        #expect(subject.snapshot.layerIndex == 2)
        #expect(subject.snapshot.textureSize == textureSize)
    }

    @Test
    func `Confirms setLayers throws when the layer array is empty`() throws {
        let subject: Subject = .init()
        try subject.setLayers([layer0], textureSize: textureSize)

        #expect(throws: NSError.self) {
            try subject.setLayers([], textureSize: textureSize)
        }
        #expect(subject.layers.map(\.id) == [layer0.id])
        #expect(subject.selectedLayer?.id == layer0.id)
    }

    @Test
    func `Confirms selectLayer setVisibility and setAlpha update the layer`() async throws {
        let subject: Subject = .init()
        try subject.setLayers([layer0, layer1], textureSize: textureSize)

        let canvas = TextureLayerCanvasUpdatingStub()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        subject.setup(device: device, commandQueue: commandQueue, canvasView: canvas)

        try await subject.selectLayer(id: layer1.id)
        try await subject.setVisibility(id: layer1.id, isVisible: false)
        subject.setAlpha(id: layer1.id, alpha: 40)

        #expect(subject.selectedLayer?.id == layer1.id)
        #expect(subject.layer(layer1.id)?.isVisible == false)
        #expect(subject.layer(layer1.id)?.alpha == 40)
        #expect(subject.selectedLayer?.alpha == 40)
    }

    @Test
    func `Confirms moveLayers reorders the layers`() async throws {
        let subject: Subject = .init()
        try subject.setLayers([layer0, layer1, layer2], textureSize: textureSize)
        let canvas = TextureLayerCanvasUpdatingStub()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        subject.setup(device: device, commandQueue: commandQueue, canvasView: canvas)

        try await subject.moveLayers(from: IndexSet(integer: 0), to: 3)

        #expect(subject.layers.map(\.id) == [layer2.id, layer0.id, layer1.id])
    }

    @Test
    func `Confirms layer operations throw when the canvas reports an unsaved drawing`() async throws {
        let subject: Subject = .init()
        try subject.setLayers([layer0, layer1], textureSize: textureSize)
        let canvas = TextureLayerCanvasUpdatingStub()
        canvas.unsavedDrawingError = TextureLayerCanvasDrawingPersistence.saveInProgressError
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        subject.setup(device: device, commandQueue: commandQueue, canvasView: canvas)

        let error = await #expect(throws: NSError.self) {
            try await subject.selectLayer(id: layer1.id)
        }
        #expect(TextureLayerCanvasDrawingPersistence.isSaveInProgressError(try #require(error)))
        #expect(subject.selectedLayer?.id == layer0.id)
    }

    @Test
    func `Confirms addLayer returns when the canvas is not set up`() async throws {
        let subject: Subject = .init()
        try subject.setLayers([layer0], textureSize: textureSize)

        try await subject.addLayer()

        #expect(subject.layers.count == 1)
    }

    @Test
    func `Confirms addLayer throws when required data is missing`() async throws {
        let subject: Subject = .init()
        try subject.setLayers([layer0], textureSize: textureSize)
        let canvas = TextureLayerCanvasUpdatingStub()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        subject.setup(device: device, commandQueue: commandQueue, canvasView: canvas)

        await #expect(throws: NSError.self) {
            try await subject.addLayer()
        }
    }
}

@MainActor
final class TextureLayerCanvasUpdatingStub: TextureLayerCanvasUpdating {

    var unsavedDrawingError: (any Error)?

    func throwIfUnsavedDrawing() throws {
        if let unsavedDrawingError { throw unsavedDrawingError }
    }

    func updateFullCanvas() async throws {}

    func updateCanvasDisplay() {}
}
