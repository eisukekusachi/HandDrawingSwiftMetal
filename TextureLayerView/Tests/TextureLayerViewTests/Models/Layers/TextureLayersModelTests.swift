//
//  TextureLayersModelTests.swift
//  TextureLayerViewTests
//
//  Created by Eisuke Kusachi on 2026/08/23.
//

import CoreGraphics
import Testing

@testable import TextureLayerView

struct TextureLayersModelTests {

    private let textureSize: CGSize = .init(width: 123, height: 456)

    @Test
    func `When archive layerIndex is negative, it is clamped to 0`() throws {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = try TextureLayersModel(
            model: .init(
                layers: layers,
                layerIndex: -3,
                textureSize: textureSize
            )
        )

        #expect(subject.layers.count == 2)
        #expect(subject.layerIndex == 0)
        #expect(subject.selectedLayerId == layers[0].id)
    }

    @Test
    func `When archive layerIndex exceeds the number of layers, it is clamped to the last layer`() throws {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = try TextureLayersModel(
            model: .init(
                layers: layers,
                layerIndex: 5,
                textureSize: textureSize
            )
        )

        #expect(subject.layers.count == 2)
        #expect(subject.layerIndex == 1)
        #expect(subject.selectedLayerId == layers[1].id)
    }

    @Test
    func `When archive layers are empty, initialization throws`() {
        #expect(throws: (any Error).self) {
            try TextureLayersModel(
                model: .init(
                    layers: [],
                    layerIndex: 0,
                    textureSize: textureSize
                )
            )
        }
    }
}
