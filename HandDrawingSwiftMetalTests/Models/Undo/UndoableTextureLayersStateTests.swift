//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import MetalKit
import Testing
import TextureLayerCanvasView
import TextureLayerView
@testable import HandDrawingSwiftMetal

@MainActor
struct UndoableTextureLayersStateTests {

    typealias Subject = UndoableTextureLayersState

    let textureSize: CGSize = .init(width: 123, height: 456)

    let layer0: TextureLayerModel = .generate(title: "layer0", isVisible: true)
    let layer1: TextureLayerModel = .generate(title: "layer1", isVisible: true)
    let layer2: TextureLayerModel = .generate(title: "layer2", isVisible: true)

    @Test
    func `Confirms renameLayer throws when undo is not set`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        do {
            try subject.renameLayer(id: layer0.id, title: "renamed")
        } catch {
            #expect((error as NSError).localizedFailureReason == "Undo is not set")
        }
        #expect(subject.layer(layer0.id)?.title == "layer0")
    }

    @Test
    func `Confirms moveLayers throws when undo is not set`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        do {
            try subject.moveLayers(from: IndexSet(integer: 0), to: 2)
        } catch {
            #expect((error as NSError).localizedFailureReason == "Undo is not set")
        }
        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id])
    }

    @Test
    func `Confirms selectLayer throws when undo is not set`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        do {
            try subject.selectLayer(id: layer1.id)
        } catch {
            #expect((error as NSError).localizedFailureReason == "Undo is not set")
        }
        #expect(subject.selectedLayer?.id == layer0.id)
    }

    @Test
    func `Confirms setVisibility throws when undo is not set`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        do {
            try subject.setVisibility(id: layer0.id, isVisible: false)
        } catch {
            #expect((error as NSError).localizedFailureReason == "Undo is not set")
        }
        #expect(subject.layer(layer0.id)?.isVisible == true)
    }

    @Test
    func `Confirms removeLayer throws when undo is not set`() async throws {
        let subject: Subject = .init()
        subject.setLayers([layer0, layer1], textureSize: textureSize)

        do {
            _ = try await subject.removeLayer(id: layer0.id)
        } catch {
            #expect((error as NSError).localizedFailureReason == "Undo is not set")
        }
        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id])
    }

    @Test
    func `Confirms renameLayer updates the title and registers undo`() async throws {
        let registered = UndoRegistration()
        let subject = try subject(layers: [layer0, layer1], registered: registered)

        try subject.renameLayer(id: layer0.id, title: "renamed")

        #expect(subject.layer(layer0.id)?.title == "renamed")
        #expect(registered.pairs.count == 1)
    }

    @Test
    func `Confirms selectLayer changes the selection and registers undo`() async throws {
        let registered = UndoRegistration()
        let subject = try subject(layers: [layer0, layer1], registered: registered)

        try subject.selectLayer(id: layer1.id)

        #expect(subject.selectedLayer?.id == layer1.id)
        #expect(registered.pairs.count == 1)
    }

    @Test
    func `Confirms setVisibility updates the layer and registers undo`() async throws {
        let registered = UndoRegistration()
        let subject = try subject(layers: [layer0, layer1], registered: registered)

        try subject.setVisibility(id: layer0.id, isVisible: false)

        #expect(subject.layer(layer0.id)?.isVisible == false)
        #expect(registered.pairs.count == 1)
    }

    @Test
    func `Confirms moveLayers reorders the layers and registers undo`() async throws {
        let registered = UndoRegistration()
        let subject = try subject(layers: [layer0, layer1, layer2], registered: registered)

        try subject.moveLayers(from: IndexSet(integer: 0), to: 3)

        #expect(subject.layers.map(\.id) == [layer2.id, layer0.id, layer1.id])
        #expect(registered.pairs.count == 1)
    }

    @Test
    func `Confirms removeLayer does nothing when the canvas is missing`() async throws {
        let repository = TextureRepositoryStub()
        let registered = UndoRegistration()
        let subject = try subject(
            layers: [layer0, layer1],
            repository: repository,
            registered: registered
        )

        let removed = try await subject.removeLayer(id: layer0.id)

        #expect(removed == false)
        #expect(subject.layers.map(\.id) == [layer0.id, layer1.id])
        #expect(registered.pairs.isEmpty)
        #expect(repository.removedIds.isEmpty)
    }

    @Test
    func `Confirms removeLayer registers the requested layer for undo`() async throws {
        let repository = TextureRepositoryStub()
        let registered = UndoRegistration()
        let subject = try subject(
            layers: [layer0, layer1],
            repository: repository,
            registered: registered
        )
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        let canvas = CanvasUpdatingStub()
        subject.setup(
            device: device,
            commandQueue: commandQueue,
            canvasView: canvas
        )

        let removed = try await subject.removeLayer(id: layer1.id)

        let undoObject = try #require(registered.pairs.first?.undoObject as? UndoAdditionObject)
        #expect(removed)
        #expect(subject.layers.map(\.id) == [layer0.id])
        #expect(undoObject.textureLayer.id == layer1.id)
        #expect(undoObject.insertIndex == 1)
        #expect(registered.pairs.first?.redoObject.textureLayer.id == layer1.id)
        #expect(repository.removedIds == [layer1.id])
    }

    private func subject(
        layers: [TextureLayerModel],
        repository: TextureRepositoryStub = TextureRepositoryStub(),
        registered: UndoRegistration
    ) throws -> Subject {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let subject: Subject = .init(repository: repository)
        subject.setLayers(layers, textureSize: textureSize)
        subject.setUndo(
            undo: .init(
                device: device,
                textureRepository: repository,
                onRegisterUndo: { registered.pairs.append($0) }
            )
        )
        return subject
    }
}

private final class UndoRegistration {
    var pairs: [UndoRedoObjectPair] = []
}

private final class CanvasUpdatingStub: TextureLayerCanvasUpdating {
    func updateFullCanvas() async throws {}
    func updateCanvasDisplay() {}
}
