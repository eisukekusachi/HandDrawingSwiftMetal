//
//  TextureLayersTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/21.
//
import Foundation
import Combine
import CoreGraphics
import Testing

@testable import CanvasView

@MainActor
struct TextureLayersTests {
/*
    func initialize_setsState_andTriggersCopy() async {
        let ids = [UUID(), UUID(), UUID()]
        let cfg = ResolvedTextureLayserArrayConfiguration(
            textureSize: .init(width: 512, height: 256),
            layers: ids.enumerated().map { (i, id) in
                TextureLayerModel(id: id, title: "L\(i)", alpha: 100, isVisible: true, thumbnail: nil)
            },
            selectedLayerId: ids[1]
        )
        let repo = MockTextureRepository()
        let sut = TextureLayers()

        await sut.initialize(configuration: cfg, textureRepository: repo, undoStack: nil)

        #expect(sut.textureSize == cfg.textureSize)
        #expect(sut.layers.map(\.id) == ids)
        #expect(sut.selectedLayerId == ids[1])

        // copyTextures が Task で呼ばれるので少し待つ
        let ok = await eventually {
            repo.copyRequests.first == ids
        }
        #expect(ok, "copyTextures(uuids:) が呼ばれていません")
    }

*/

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
            texture: nil,
            at: 0
        )

        // The layer count increases by one, and the newly added layer is selected
        #expect(subject.layers.count == 1)
        #expect(subject.layers[0].id == layer0.id)
        #expect(subject.selectedLayerId == layer0.id)

        let layer1: TextureLayerItem = .init(id: UUID(), title: "New1", alpha: 255, isVisible: true, thumbnail: nil)

        try await subject.addLayer(
            layer: layer1,
            texture: nil,
            at: 1
        )

        // The layer count increases by one, and the newly added layer is selected
        #expect(subject.layers.count == 2)
        #expect(subject.layers[1].id == layer1.id)
        #expect(subject.selectedLayerId == layer1.id)
    }

    func testRemoveLayer() async throws {

        let subject = TextureLayers()

        await subject.initialize(
            configuration: .init(
                textureSize: .init(width: 16, height: 16),
                layerIndex: 0,
                layers: []
            ),
            textureRepository: MockTextureRepository()
        )

        try await subject.removeLayer(layerIndexToDelete: 1)

        #expect(subject.layers.count == 1)

        #expect(subject.selectedLayerId != nil)
    }

    /*
    func moveLayer_reorders_andPublishesFullUpdate() async {
        let ids = [UUID(), UUID(), UUID()]
        let sut = TextureLayers()
        sut._layers = ids.enumerated().map {
            TextureLayerItem(id: $0.element, title: "L\($0.offset)", alpha: 100, isVisible: true, thumbnail: nil)
        }

        let first = await firstValue(from: sut.fullCanvasUpdateRequestedPublisher)
        #expect(first == nil) // まだ発火していない

        // 末尾を先頭へ（MoveLayerIndices の型に合わせて作成）
        let indices = MoveLayerIndices(sourceIndexSet: IndexSet(integer: 2), destinationIndex: 0)
        sut.moveLayer(indices: indices)

        let fired = await firstValue(from: sut.fullCanvasUpdateRequestedPublisher)
        #expect(fired != nil, "fullCanvasUpdateRequestedPublisher が発火していません")
        #expect(sut.layers.count == 3)
    }

    // MARK: selectLayer()

    @Test @MainActor
    func selectLayer_setsSelected_andPublishesFullUpdate() async {
        let id = UUID()
        let sut = TextureLayers()
        sut._layers = [TextureLayerItem(id: id, title: "A", alpha: 100, isVisible: true, thumbnail: nil)]

        sut.selectLayer(id: id)
        let fired = await firstValue(from: sut.fullCanvasUpdateRequestedPublisher)
        #expect(fired != nil)
        #expect(sut.selectedLayerId == id)
    }

    // MARK: updateTitle()

    @Test @MainActor
    func updateTitle_changesOnlyTitle() {
        let id = UUID()
        let sut = TextureLayers()
        sut._layers = [TextureLayerItem(id: id, title: "Old", alpha: 11, isVisible: true, thumbnail: nil)]

        sut.updateTitle(id: id, title: "New")

        #expect(sut.layers.first?.title == "New")
        #expect(sut.layers.first?.alpha == 11)
        #expect(sut.layers.first?.isVisible == true)
    }

    // MARK: updateVisibility()

    @Test @MainActor
    func updateVisibility_changesFlag_andPublishesFullUpdate() async {
        let id = UUID()
        let sut = TextureLayers()
        sut._layers = [TextureLayerItem(id: id, title: "L", alpha: 100, isVisible: false, thumbnail: nil)]

        sut.updateVisibility(id: id, isVisible: true)
        let fired = await firstValue(from: sut.fullCanvasUpdateRequestedPublisher)
        #expect(fired != nil)
        #expect(sut.layers.first?.isVisible == true)
    }

    // MARK: updateAlpha()

    @Test @MainActor
    func updateAlpha_changesOnlyAlpha_andPublishesCanvasUpdate() async {
        let id = UUID()
        let sut = TextureLayers()
        sut._layers = [TextureLayerItem(id: id, title: "L", alpha: 10, isVisible: true, thumbnail: nil)]

        sut.updateAlpha(id: id, alpha: 42, isStartHandleDragging: false)

        let fired = await firstValue(from: sut.canvasUpdateRequestedPublisher)
        #expect(fired != nil)
        #expect(sut.layers.first?.alpha == 42)
        #expect(sut.layers.first?.title == "L")
    }

    // MARK: undoAlphaObject()

    @Test @MainActor
    func undoAlphaObject_buildsUndoRedo_onDragEnd() {
        let id = UUID()
        let sut = TextureLayers()
        sut._layers = [TextureLayerItem(id: id, title: "L", alpha: 10, isVisible: true, thumbnail: nil)]
        sut._selectedLayerId = id

        // drag start → oldAlpha を記録
        #expect(sut.undoAlphaObject(dragging: true) == nil)

        // 値変更
        sut.updateAlpha(id: id, alpha: 99, isStartHandleDragging: false)

        // drag end → Undo/Redo を返す
        let model = sut.undoAlphaObject(dragging: false)
        #expect(model != nil)
        #expect(model?.undoObject != nil)
        #expect(model?.redoObject != nil)
    }

    // MARK: undoAddition / undoDeletion / undoMove

    @Test @MainActor
    func undoAdditionObject_returnsModel() {
        let ids = [UUID(), UUID()]
        let sut = TextureLayers()
        sut._layers = ids.map { TextureLayerItem(id: $0, title: "L", alpha: 100, isVisible: true, thumbnail: nil) }

        let model = TextureLayerModel(item: sut.layers[1])
        let result = sut.undoAdditionObject(
            previousLayerIndex: 0,
            currentLayerIndex: 1,
            layer: model,
            texture: nil
        )
        #expect(result != nil)
        #expect(result?.undoObject != nil)
        #expect(result?.redoObject != nil)
    }

    @Test @MainActor
    func undoDeletionObject_returnsModel() {
        let ids = [UUID(), UUID(), UUID()]
        let sut = TextureLayers()
        sut._layers = ids.map { TextureLayerItem(id: $0, title: "L", alpha: 100, isVisible: true, thumbnail: nil) }

        let model = TextureLayerModel(item: sut.layers[1])
        let result = sut.undoDeletionObject(
            previousLayerIndex: 1,
            currentLayerIndex: 2,
            layer: model,
            texture: nil
        )
        #expect(result != nil)
        #expect(result?.undoObject != nil)
        #expect(result?.redoObject != nil)
    }

    @Test @MainActor
    func undoMoveObject_returnsModel_andReversed() {
        let ids = [UUID(), UUID(), UUID()]
        let sut = TextureLayers()
        sut._layers = ids.map { TextureLayerItem(id: $0, title: "L", alpha: 100, isVisible: true, thumbnail: nil) }

        let indices = MoveLayerIndices(sourceIndexSet: IndexSet(integer: 0), destinationIndex: 2)
        let selectedId = ids[1]
        let model = TextureLayerModel(item: sut.layers[0])

        let result = sut.undoMoveObject(indices: indices, selectedLayerId: selectedId, textureLayer: model)
        #expect(result != nil)
        #expect(result?.undoObject != nil)
        #expect(result?.redoObject != nil)
    }
     */
}
