//
//  TextureLayersSnapshotTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2026/08/23.
//

import CoreGraphics
import Testing

@testable import HandDrawingSwiftMetal

struct TextureLayersSnapshotTests {

    private let textureSize: CGSize = .init(width: 123, height: 456)

    @Test
    func `When layers is empty, one layer is created`() {
        let subject = TextureLayersSnapshot(
            textureSize: textureSize,
            title: "blank"
        )

        #expect(subject.layers.count == 1)
        #expect(subject.layers[0].title == "blank")
        #expect(subject.layerIndex == 0)
    }

    @Test
    func `When layerIndex is negative, it is clamped to 0`() {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = TextureLayersSnapshot(
            layers: layers,
            layerIndex: -3,
            textureSize: textureSize
        )

        #expect(subject.layers.count == 2)
        #expect(subject.layerIndex == 0)
        #expect(subject.selectedLayerId == layers[0].id)
    }

    @Test
    func `When layerIndex exceeds the number of layers, it is clamped to the last layer`() {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = TextureLayersSnapshot(
            layers: layers,
            layerIndex: 5,
            textureSize: textureSize
        )

        #expect(subject.layers.count == 2)
        #expect(subject.layerIndex == 1)
        #expect(subject.selectedLayerId == layers[1].id)
    }
}
