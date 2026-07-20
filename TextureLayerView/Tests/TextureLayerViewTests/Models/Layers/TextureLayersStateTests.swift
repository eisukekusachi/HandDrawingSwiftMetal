//
//  TextureLayersStateTests.swift
//  TextureLayerViewTests
//
//  Created by Eisuke Kusachi on 2025/12/30.
//

import CoreGraphics
import UIKit
import Testing

@testable import TextureLayerView

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
            let subject = Subject(
                textureLayers: .init(
                    layers: [
                        layer0,
                        layer1,
                        layer2
                    ],
                    layerIndex: 1,
                    textureSize: textureSize
                )
            )

            #expect(subject.layers.count == 3)
            #expect(subject.selectedIndex == 1)
            #expect(subject.textureSize.width == textureSize.width)
            #expect(subject.textureSize.height == textureSize.height)
        }

        @Test
        func `When the layers argument is empty, a default layer is created and layerIndex is set to 0`() {
            let subject = Subject(
                textureLayers: .init(
                    textureSize: textureSize
                )
            )

            // layers array is never empty
            #expect(subject.layers.count == 1)
            #expect(subject.selectedIndex == 0)
            #expect(subject.textureSize.width == textureSize.width)
            #expect(subject.textureSize.height == textureSize.height)
        }

        @Test
        func `When layerIndex exceeds the number of layers, it is clamped to the last layer`() {
            let subject = Subject(
                textureLayers: .init(
                    layers: [
                        .generate(),
                        .generate(),
                    ],
                    layerIndex: 3,
                    textureSize: textureSize
                )
            )

            #expect(subject.layers.count == 2)
            #expect(subject.selectedIndex == 1)
        }
    }
}
