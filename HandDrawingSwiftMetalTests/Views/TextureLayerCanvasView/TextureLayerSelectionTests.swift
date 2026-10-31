//
//  Created by Eisuke Kusachi
//

import Foundation
import Testing
import TextureLayerView

@testable import HandDrawingSwiftMetal

@MainActor
struct TextureLayerSelectionTests {

    private func layers(_ count: Int) -> [TextureLayerItem] {
        (0..<count).map { _ in
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

        #expect(subject.bottomLayers.map(\.id) == [])
        #expect(subject.topLayers.map(\.id) == [layers[1].id, layers[2].id, layers[3].id, layers[4].id])
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

        #expect(subject.bottomLayers.map(\.id) == [layers[0].id, layers[1].id])
        #expect(subject.topLayers.map(\.id) == [layers[3].id, layers[4].id])
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

        #expect(subject.bottomLayers.map(\.id) == [layers[0].id, layers[1].id, layers[2].id, layers[3].id])
        #expect(subject.topLayers.map(\.id) == [])
    }

    @Test
    func `Verify that layers with isVisible set to false are not included in the array`() {
        let layers = [
            TextureLayerItem(id: UUID(), alpha: 255, isVisible: true),
            TextureLayerItem(id: UUID(), alpha: 255, isVisible: false),
            TextureLayerItem(id: UUID(), alpha: 255, isVisible: true),
            TextureLayerItem(id: UUID(), alpha: 255, isVisible: true),
            TextureLayerItem(id: UUID(), alpha: 255, isVisible: false)
        ]

        let subject = TextureLayerSelection(
            textureLayers: .init(
                selectedIndex: 2,
                layers: layers
            )
        )

        #expect(subject.bottomLayers.map(\.id) == [layers[0].id])
        #expect(subject.topLayers.map(\.id) == [layers[3].id])
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
