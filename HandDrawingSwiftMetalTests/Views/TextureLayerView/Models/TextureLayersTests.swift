//
//  TextureLayersTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/07.
//

import XCTest
import Combine
@testable import HandDrawingSwiftMetal

final class TextureLayersTests: XCTestCase {

    var subject: TextureLayers!

    let selectedLayerIndex = 3
    let layerCount = 5

    var blankTexture: MTLTexture!
    var currentTexture: MTLTexture!
    var destinationTexture: MTLTexture!

    var commandBuffer: MTLCommandBuffer!
    let device = MTLCreateSystemDefaultDevice()!

    let renderer = MockMTLRenderer()

    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = "commandBuffer"

        var layers: [TextureLayer] = []

        for i in 0 ..< layerCount {
            let texture = MTLTextureCreator.makeBlankTexture(
                size: MTLRenderer.minimumTextureSize,
                with: device
            )
            texture?.label = "texture\(i)"
            layers.append(.generate(texture: texture))
        }

        subject = TextureLayers(renderer: renderer)
        subject.initLayers(layers: layers)
        subject.index = selectedLayerIndex

        blankTexture = MTLTextureCreator.makeBlankTexture(
            size: MTLRenderer.minimumTextureSize,
            with: device
        )!
        blankTexture.label = "blankTexture"

        currentTexture = MTLTextureCreator.makeBlankTexture(
            size: MTLRenderer.minimumTextureSize,
            with: device
        )!
        currentTexture.label = "currentTexture"

        destinationTexture = MTLTextureCreator.makeBlankTexture(
            size: MTLRenderer.minimumTextureSize,
            with: device
        )!
        destinationTexture.label = "destinationTexture"

        renderer.callHistory.removeAll()
    }

    func testIsTextureInitialized_whenInitLayersIsSuccessful() {
        let subject = TextureLayers(renderer: renderer)

        XCTAssertEqual(subject.isTextureInitialized, false)

        subject.initLayers(layers: [
            .generate(texture: blankTexture)
        ])

        XCTAssertEqual(subject.isTextureInitialized, true)
    }
    func testIsTextureInitialized_whenInitLayersFails() {
        let subject = TextureLayers(renderer: renderer)

        XCTAssertEqual(subject.isTextureInitialized, false)

        subject.initLayers(layers: [])

        XCTAssertEqual(subject.isTextureInitialized, false)
    }

    /// Confirms that the texture of the unselected layers is merged into one texture
    func testUpdateUnselectedTexturesIfNeeded() {
        struct Condition: Hashable {
            var index: Int
        }
        struct Expectation {
            var result: String
        }

        let testCases: [Condition: Expectation] = [
            // When the selected layer is at the bottom,
            // the layers above it are merged into `unselectedTopTexture`,
            // while the layers below it are not merged, and `unselectedBottomTexture` is simply cleared.
            .init(index: 0): .init(
                result: [
                    // unselectedBottomTexture
                    "clearTexture(texture: unselectedBottomTexture, with: commandBuffer)",
                    // unselectedTopTexture
                    "clearTexture(texture: unselectedTopTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture1, alpha: 255, into: unselectedTopTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture2, alpha: 255, into: unselectedTopTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture3, alpha: 255, into: unselectedTopTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture4, alpha: 255, into: unselectedTopTexture, with: commandBuffer)"
                ].joined()
            ),
            // When the selected layer is at the top,
            // the layers below it are merged into `unselectedBottomTexture`,
            // while the layers above it are not merged, and `unselectedTopTexture` is simply cleared.
            .init(index: 4): .init(
                result: [
                    // unselectedBottomTexture
                    "clearTexture(texture: unselectedBottomTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture0, alpha: 255, into: unselectedBottomTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture1, alpha: 255, into: unselectedBottomTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture2, alpha: 255, into: unselectedBottomTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture3, alpha: 255, into: unselectedBottomTexture, with: commandBuffer)",
                    // unselectedTopTexture
                    "clearTexture(texture: unselectedTopTexture, with: commandBuffer)"
                ].joined()
            ),
            // When the selected layer is neither at the top nor the bottom,
            // the layers below it are merged into `unselectedBottomTexture`, and the layers above it are merged into `unselectedTopTexture`.
            .init(index: 2): .init(
                result: [
                    // unselectedBottomTexture
                    "clearTexture(texture: unselectedBottomTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture0, alpha: 255, into: unselectedBottomTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture1, alpha: 255, into: unselectedBottomTexture, with: commandBuffer)",
                    // unselectedTopTexture
                    "clearTexture(texture: unselectedTopTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture3, alpha: 255, into: unselectedTopTexture, with: commandBuffer)",
                    "mergeTexture(texture: texture4, alpha: 255, into: unselectedTopTexture, with: commandBuffer)"
                ].joined()
            )
        ]

        testCases.forEach { testCase in
            subject.index = testCase.key.index
            subject.updateUnselectedTexturesIfNeeded(commandBuffer: commandBuffer)

            XCTAssertEqual(renderer.callHistory.joined(), testCase.value.result)
            renderer.callHistory.removeAll()
        }
    }

    /// Confirms that `currentTexture` and unselected textures are combined and drawn into `destinationTexture`
    func testMakeTextureFromUnselectedTextures() {
        struct Condition {
            var currentTexture: MTLTexture?
            var isSelectedLayerVisible: Bool
        }
        struct Expectation {
            var result: String
        }

        let testCases: [(Condition, Expectation)] = [
            (
                .init(currentTexture: currentTexture, isSelectedLayerVisible: true),
                .init(
                    result:
                        [
                            "fillTexture(texture: destinationTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                            "mergeTexture(texture: unselectedBottomTexture, into: destinationTexture, with: commandBuffer)",
                            "mergeTexture(texture: currentTexture, alpha: 255, into: destinationTexture, with: commandBuffer)",
                            "mergeTexture(texture: unselectedTopTexture, into: destinationTexture, with: commandBuffer)"
                        ].joined()
                )
            ),
            (
                // When `currentTexture` is nil, the texture of the currently selected layer will be assigned.
                .init(currentTexture: nil, isSelectedLayerVisible: true),
                .init(
                    result:
                        [
                            "fillTexture(texture: destinationTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                            "mergeTexture(texture: unselectedBottomTexture, into: destinationTexture, with: commandBuffer)",
                            "mergeTexture(texture: texture3, alpha: 255, into: destinationTexture, with: commandBuffer)",
                            "mergeTexture(texture: unselectedTopTexture, into: destinationTexture, with: commandBuffer)"
                        ].joined()
                )
            ),
            (
                // When the selected layer is hidden, `currentTexture` will not be drawn
                .init(currentTexture: currentTexture, isSelectedLayerVisible: false),
                .init(
                    result:
                        [
                            "fillTexture(texture: destinationTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                            "mergeTexture(texture: unselectedBottomTexture, into: destinationTexture, with: commandBuffer)",
                            "mergeTexture(texture: unselectedTopTexture, into: destinationTexture, with: commandBuffer)"
                        ].joined()
                )
            ),
            (
                // When the selected layer is hidden, the texture of the currently selected layer will not be drawn
                .init(currentTexture: nil, isSelectedLayerVisible: false),
                .init(
                    result:
                        [
                            "fillTexture(texture: destinationTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                            "mergeTexture(texture: unselectedBottomTexture, into: destinationTexture, with: commandBuffer)",
                            "mergeTexture(texture: unselectedTopTexture, into: destinationTexture, with: commandBuffer)"
                        ].joined()
                )
            ),
        ]

        testCases.forEach { testCase in
            let condition = testCase.0
            let expectation = testCase.1

            subject.layers[selectedLayerIndex].isVisible = condition.isSelectedLayerVisible
            subject.makeTextureFromUnselectedTextures(
                usingCurrentTexture: condition.currentTexture,
                to: destinationTexture,
                with: commandBuffer
            )

            XCTAssertEqual(renderer.callHistory.joined(), expectation.result)
            renderer.callHistory.removeAll()
        }
    }

}
