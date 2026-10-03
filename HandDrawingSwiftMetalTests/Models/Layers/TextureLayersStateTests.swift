//
//  TextureLayersStateTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/12/30.
//

import CoreGraphics
import Testing
import TextureLayerView
import UIKit

@testable import HandDrawingSwiftMetal

struct TextureLayersStateTests {

    private typealias Subject = TextureLayersState

    @MainActor
    struct DefaultTests {
        let textureSize: CGSize = .init(width: 123, height: 456)

        let layer0: TextureLayerModel = .init(id: LayerId(), title: "layer0", alpha: 0, isVisible: true)
        let layer1: TextureLayerModel = .init(id: LayerId(), title: "layer1", alpha: 1, isVisible: true)
        let layer2: TextureLayerModel = .init(id: LayerId(), title: "layer2", alpha: 2, isVisible: false)

        @Test
        func `When the layers argument is provided, it is set as-is`() {
            let subject = Subject()
            subject.setLayers(
                [layer0, layer1, layer2],
                textureSize: textureSize,
                selectedIndex: 1
            )

            #expect(subject.layers.count == 3)
            #expect(subject.selectedIndex == 1)
            #expect(subject.textureSize.width == textureSize.width)
            #expect(subject.textureSize.height == textureSize.height)
        }

        @Test
        func `When selectedIndex exceeds the number of layers, it is clamped to the last layer`() {
            let subject = Subject()
            subject.setLayers(
                [.generate(), .generate()],
                textureSize: textureSize,
                selectedIndex: 3
            )

            #expect(subject.layers.count == 2)
            #expect(subject.selectedIndex == 1)
        }

        @Test
        func `When selectedIndex is negative, it is clamped to 0`() {
            let subject = Subject()
            subject.setLayers(
                [layer0, layer1, layer2],
                textureSize: textureSize,
                selectedIndex: -1
            )

            #expect(subject.layers.count == 3)
            #expect(subject.selectedIndex == 0)
        }
    }

    @MainActor
    struct RemoveLayerTests {
        let textureSize: CGSize = .init(width: 123, height: 456)

        let layer0: TextureLayerModel = .init(id: LayerId(), title: "layer0", alpha: 0, isVisible: true)
        let layer1: TextureLayerModel = .init(id: LayerId(), title: "layer1", alpha: 1, isVisible: true)

        @Test
        func `When the index is out of bounds, removeLayer returns false and layers stay unchanged`() {
            let subject = Subject()
            subject.setLayers(
                [layer0, layer1],
                textureSize: textureSize
            )

            let result = subject.removeLayer(layerIndexToDelete: 2)

            #expect(result == false)
            #expect(subject.layers.count == 2)
            #expect(subject.selectedIndex == 0)
        }

        @Test
        func `When only one layer remains, removeLayer returns false`() {
            let subject = Subject()
            subject.setLayers(
                [layer0],
                textureSize: textureSize
            )

            let result = subject.removeLayer(layerIndexToDelete: 0)

            #expect(result == false)
            #expect(subject.layers.count == 1)
            #expect(subject.selectedIndex == 0)
        }
    }
}
