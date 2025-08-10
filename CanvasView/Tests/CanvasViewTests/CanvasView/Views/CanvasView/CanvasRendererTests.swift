//
//  CanvasRendererTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import XCTest

@testable import CanvasView

final class CanvasRendererTests: XCTestCase {

    let device = MTLCreateSystemDefaultDevice()!

    /// Confirms that the canvas is updated correctly depending on the presence of the realtime drawing texture and the visibility of the selected layer.
    @MainActor
    func testUpdateCanvasView() {
        struct Condition {
            let hasRealtimeDrawingTexture: Bool
            let isLayerVisible: Bool
        }
        struct Expectation {
            let result: [String]
        }

        let selectedTextureLabel = "selectedTexture"
        let realtimeDrawingTextureLabel = "realtimeDrawingTexture"

        let testCases: [(Condition, Expectation)] = [
            (
                // When `realtimeDrawingTexture` is unavailable and `isLayerVisible` is true, render `selectedTexture`.
                .init(
                    hasRealtimeDrawingTexture: false,
                    isLayerVisible: true
                ),
                .init(
                    result: [
                        "fillTexture(texture: canvasTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                        "mergeTexture(texture: unselectedBottomTexture, into: canvasTexture, with: commandBuffer)",
                        "mergeTexture(texture: \(selectedTextureLabel), alpha: 255, into: canvasTexture, with: commandBuffer)",
                        "mergeTexture(texture: unselectedTopTexture, into: canvasTexture, with: commandBuffer)"
                    ]
                )
            ),
            (
                // When `realtimeDrawingTexture` is available and `isLayerVisible` is true, render `realtimeDrawingTexture`.
                .init(
                    hasRealtimeDrawingTexture: true,
                    isLayerVisible: true
                ),
                .init(
                    result: [
                        "fillTexture(texture: canvasTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                        "mergeTexture(texture: unselectedBottomTexture, into: canvasTexture, with: commandBuffer)",
                        "mergeTexture(texture: \(realtimeDrawingTextureLabel), alpha: 255, into: canvasTexture, with: commandBuffer)",
                        "mergeTexture(texture: unselectedTopTexture, into: canvasTexture, with: commandBuffer)"
                    ]
                )
            ),
            (
                // When `isLayerVisible` is false, neither `selectedTexture` nor `realtimeDrawingTexture` is rendered.
                .init(
                    hasRealtimeDrawingTexture: false,
                    isLayerVisible: false
                ),
                .init(
                    result: [
                        "fillTexture(texture: canvasTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                        "mergeTexture(texture: unselectedBottomTexture, into: canvasTexture, with: commandBuffer)",
                        "mergeTexture(texture: unselectedTopTexture, into: canvasTexture, with: commandBuffer)"
                    ]
                )
            ),
            (
                // When `isLayerVisible` is false, neither `selectedTexture` nor `realtimeDrawingTexture` is rendered.
                .init(
                    hasRealtimeDrawingTexture: true,
                    isLayerVisible: false
                ),
                .init(
                    result: [
                        "fillTexture(texture: canvasTexture, withRGB: (255, 255, 255), with: commandBuffer)",
                        "mergeTexture(texture: unselectedBottomTexture, into: canvasTexture, with: commandBuffer)",
                        "mergeTexture(texture: unselectedTopTexture, into: canvasTexture, with: commandBuffer)"
                    ]
                )
            )
        ]

        let realtimeDrawingTexture = MTLTextureCreator.makeBlankTexture(label: realtimeDrawingTextureLabel, with: device)

        let canvasView = MockCanvasDisplayable()

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = "commandBuffer"

        for testCase in testCases {
            let condition = testCase.0
            let expectation = testCase.1

            let mockRenderer = MockMTLRenderer()

            let subject = CanvasRenderer(
                renderer: mockRenderer
            )
            subject.initTextures(textureSize: MTLRenderer.minimumTextureSize)

            subject.updateCanvasView(
                canvasView,
                realtimeDrawingTexture: condition.hasRealtimeDrawingTexture ? realtimeDrawingTexture : nil,
                selectedLayer: .generate(
                    id: UUID(),
                    title: "TestLayer",
                    isVisible: condition.isLayerVisible
                ),
                with: commandBuffer
            )

            XCTAssertEqual(mockRenderer.callHistory, expectation.result)
        }
    }

    /// Confirms that unselected layers are split into `topLayers` and `bottomLayers` relative to the selected layer index, excluding invisible layers.
    @MainActor
    func testUnselectedLayersAreSeparatedIntoTopAndBottomArrays() {
        struct Condition {
            let layers: [TextureLayerItem]
            let selectedLayerIndex: Int
        }
        struct Expectation {
            let expectationBottomLayers: [TextureLayerItem]
            let expectationTopLayers: [TextureLayerItem]
        }

        let testCases: [(Condition, Expectation)] = [
            (
                // All layers except the selected one are grouped into `topLayers` and `bottomLayers`.
                .init(
                    layers: [
                        .generate(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    selectedLayerIndex: 2
                ),
                .init(
                    expectationBottomLayers: [
                        .generate(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    expectationTopLayers: [
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                )
            ),
            (
                // If the selected layer is at the top, `topLayers` will be empty.
                .init(
                    layers: [
                        .generate(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    selectedLayerIndex: 4
                ),
                .init(
                    expectationBottomLayers: [
                        .generate(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    expectationTopLayers: []
                )
            ),
            (
                // If the selected layer is at the bottom, `bottomLayers` will be empty.
                .init(
                    layers: [
                        .generate(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    selectedLayerIndex: 0
                ),
                .init(
                    expectationBottomLayers: [],
                    expectationTopLayers: [
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .generate(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                )
            ),
            (
                // Layers with `isVisible` set to `false` are excluded from both arrays.
                .init(
                    layers: [
                        .generate(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: "", isVisible: false),
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true),
                        .generate(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true),
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true),
                        .generate(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "", isVisible: false)
                    ],
                    selectedLayerIndex: 2
                ),
                .init(
                    expectationBottomLayers: [
                        .generate(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true)
                    ],
                    expectationTopLayers: [
                        .generate(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true)
                    ]
                )
            )
        ]

        for testCase in testCases {
            let condition = testCase.0
            let expectation = testCase.1

            let subject = CanvasRenderer()

            XCTAssertEqual(
                subject.bottomLayers(selectedIndex: condition.selectedLayerIndex, layers: condition.layers),
                expectation.expectationBottomLayers
            )
            XCTAssertEqual(
                subject.topLayers(selectedIndex: condition.selectedLayerIndex, layers: condition.layers),
                expectation.expectationTopLayers
            )
        }
    }
}
