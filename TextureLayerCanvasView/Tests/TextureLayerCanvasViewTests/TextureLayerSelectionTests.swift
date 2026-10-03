//
//  TextureLayerSelectionTests.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/22.
//

import Testing

@testable import TextureLayerCanvasView

@MainActor
struct TextureLayerSelectionTests {

    private func layers(_ count: Int) -> [CanvasLayerSnapshot] {
        (0..<count).map {
            .init(id: UUID(), alpha: 255, isVisible: true)
        }
    }

    @Test
    func `Verify that when the bottom-most layer is selected, bottomLayers contains nothing`() {

        let layers = layers(5)

        let subject: TextureLayerSelection = .init(
            textureLayers: .init(
                selectedIndex: 0,
                layers: layers
            )
        )

        #expect(subject.bottomLayers == [])
        #expect(subject.topLayers == [layers[1], layers[2], layers[3], layers[4]])
    }

    @Test
    func `Verify that when the middle layer is selected, topLayers and bottomLayers contains layers`() {

        let layers = layers(5)

        let subject: TextureLayerSelection = .init(
            textureLayers: .init(
                selectedIndex: 2,
                layers: layers
            )
        )

        #expect(subject.bottomLayers == [layers[0], layers[1]])
        #expect(subject.topLayers == [layers[3], layers[4]])
    }

    @Test
    func `Verify that when the top-most layer is selected, topLayers contains nothing`() {

        let layers = layers(5)

        let subject: TextureLayerSelection = .init(
            textureLayers: .init(
                selectedIndex: 4,
                layers: layers
            )
        )

        #expect(subject.bottomLayers == [layers[0], layers[1], layers[2], layers[3]])
        #expect(subject.topLayers == [])
    }

    @Test
    func `Verify that layers with isVisible set to false are not included in the array`() {
        let layers = [
            CanvasLayerSnapshot(id: UUID(), alpha: 255, isVisible: true),
            CanvasLayerSnapshot(id: UUID(), alpha: 255, isVisible: false),
            CanvasLayerSnapshot(id: UUID(), alpha: 255, isVisible: true),
            CanvasLayerSnapshot(id: UUID(), alpha: 255, isVisible: true),
            CanvasLayerSnapshot(id: UUID(), alpha: 255, isVisible: false)
        ]

        let subject = TextureLayerSelection(
            textureLayers: .init(
                selectedIndex: 2,
                layers: layers
            )
        )

        #expect(subject.bottomLayers == [layers[0]])
        #expect(subject.topLayers == [layers[3]])
    }

    @Test
    func `Verify that the selected layer is excluded from topLayers and bottomLayers`() {
        let layers = layers(3)
        let subject = TextureLayerSelection(
            textureLayers: .init(
                selectedIndex: 1,
                layers: layers
            )
        )

        let selected = layers[1].id

        #expect(!subject.bottomLayers.contains { $0.id == selected })
        #expect(!subject.topLayers.contains { $0.id == selected })
    }
}
