//
//  CanvasRendererTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasRendererTests: XCTestCase {

    let device = MTLCreateSystemDefaultDevice()!

    /// Confirms that the canvas is updated correctly depending on the presence of the realtime drawing texture and the visibility of the selected layer
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
                // When `realtimeDrawingTexture` is unavailable and `isLayerVisible` is true, render `selectedTexture`
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
                // When `realtimeDrawingTexture` is available and `isLayerVisible` is true, render `realtimeDrawingTexture`
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
                // When `isLayerVisible` is false, neither `selectedTexture` nor `realtimeDrawingTexture` is rendered
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
                // When `isLayerVisible` is false, neither `selectedTexture` nor `realtimeDrawingTexture` is rendered
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

        let canvasView = MockCanvasViewProtocol()

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
                selectedLayer: .init(title: "TestLayer", isVisible: condition.isLayerVisible),
                with: commandBuffer
            )

            XCTAssertEqual(mockRenderer.callHistory, expectation.result)
        }
    }

    /// Confirms that unselected layers are split into `topLayers` and `bottomLayers` relative to the selected layer index, excluding invisible layers.
    func testUnselectedLayersAreSeparatedIntoTopAndBottomArrays() {
        struct Condition {
            let layers: [TextureLayerModel]
            let selectedLayerIndex: Int
        }
        struct Expectation {
            let expectationBottomLayers: [TextureLayerModel]
            let expectationTopLayers: [TextureLayerModel]
        }

        let testCases: [(Condition, Expectation)] = [
            (
                // All layers except the selected one are grouped into `topLayers` and `bottomLayers`
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    selectedLayerIndex: 2
                ),
                .init(
                    expectationBottomLayers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    expectationTopLayers: [
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                )
            ),
            (
                // If the selected layer is at the top, `topLayers` will be empty
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    selectedLayerIndex: 4
                ),
                .init(
                    expectationBottomLayers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    expectationTopLayers: []
                )
            ),
            (
                // If the selected layer is at the bottom, `bottomLayers` will be empty.
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ],
                    selectedLayerIndex: 0
                ),
                .init(
                    expectationBottomLayers: [],
                    expectationTopLayers: [
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                )
            ),
            (
                // Layers with `isVisible` set to `false` are excluded from both arrays.
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: "", isVisible: false),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true),
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true),
                        .init(id: UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!, title: "", isVisible: false)
                    ],
                    selectedLayerIndex: 2
                ),
                .init(
                    expectationBottomLayers: [
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true)
                    ],
                    expectationTopLayers: [
                        .init(id: UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!, title: "", isVisible: true)
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

    /// Confirms that a texture loaded from the repository is drawn onto the destination texture.
    func testRenderTextureFromRepositoryToTexturePublisher() {
        let expectation = XCTestExpectation()

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = "commandBuffer"

        let sourceTextureId0 = UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!
        let sourceTextureId1 = UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!
        let sourceTextureId2 = UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!

        let destinationTexture = MTLTextureCreator.makeBlankTexture(label: "destinationTexture", with: device)!

        let layer = TextureLayerModel(id: sourceTextureId1, title: "")

        let mockRenderer = MockMTLRenderer()

        let textureRepository = MockTextureRepository.init(
            textures: [
                sourceTextureId0: MTLTextureCreator.makeBlankTexture(label: "sourceTexture0", with: device)!,
                sourceTextureId1: MTLTextureCreator.makeBlankTexture(label: "sourceTexture1", with: device)!,
                sourceTextureId2: MTLTextureCreator.makeBlankTexture(label: "sourceTexture2", with: device)!
            ]
        )

        let canvasRenderer = CanvasRenderer(
            renderer: mockRenderer
        )
        canvasRenderer.setTextureRepository(textureRepository)

        let results = [
            "clearTexture(texture: destinationTexture, with: commandBuffer)",
            "mergeTexture(texture: sourceTexture1, alpha: 255, into: destinationTexture, with: commandBuffer)"
        ]

        _ = canvasRenderer.mergeLayerTextures(
            layers: [layer],
            into: destinationTexture,
            with: commandBuffer
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Expected success, got error: \(error)")
                }
                XCTAssertEqual(mockRenderer.callHistory, results)

                mockRenderer.callHistory.removeAll()
                expectation.fulfill()
            },
            receiveValue: { _ in }
        )

        wait(for: [expectation], timeout: 1.0)
    }

    /// Confirms that all visible textures loaded from the repository are merged into the destination texture
    func testMergeLayerTextures() {
        let device = MTLCreateSystemDefaultDevice()!

        let sourceTextureId0 = UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!
        let sourceTextureId1 = UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!
        let sourceTextureId2 = UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!
        let sourceTextureId3 = UUID(uuidString: "00000003-1234-4abc-8def-1234567890ab")!
        let sourceTextureId4 = UUID(uuidString: "00000004-1234-4abc-8def-1234567890ab")!

        let destinationTexture = MTLTextureCreator.makeBlankTexture(label: "destinationTexture", with: device)!

        let mockRenderer = MockMTLRenderer()

        struct Condition {
            let textureLayers: [TextureLayerModel]
        }
        struct Expectation {
            let results: [String]
        }

        let testCases: [(Condition, Expectation)] = [
            (
                .init(textureLayers: []),
                .init(results: [
                    "clearTexture(texture: destinationTexture, with: commandBuffer)"
                ])
            ),
            (
                .init(
                    textureLayers: [
                        .generate(id: sourceTextureId0),
                        .generate(id: sourceTextureId1),
                        .generate(id: sourceTextureId2)
                    ]
                ),
                .init(results: [
                    "clearTexture(texture: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture0, alpha: 255, into: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture1, alpha: 255, into: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture2, alpha: 255, into: destinationTexture, with: commandBuffer)"
                ])
            ),
            (
                .init(
                    textureLayers: [
                        .generate(id: sourceTextureId0),
                        .generate(id: sourceTextureId1),
                        .generate(id: sourceTextureId2),
                        .generate(id: sourceTextureId3),
                        .generate(id: sourceTextureId4)
                    ]
                ),
                .init(results: [
                    "clearTexture(texture: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture0, alpha: 255, into: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture1, alpha: 255, into: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture2, alpha: 255, into: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture3, alpha: 255, into: destinationTexture, with: commandBuffer)",
                    "mergeTexture(texture: sourceTexture4, alpha: 255, into: destinationTexture, with: commandBuffer)"
                ])
            )
        ]

        for testCase in testCases {
            let expectation = XCTestExpectation()

            let condition = testCase.0
            let results = testCase.1

            let textureRepository = MockTextureRepository.init(
                textures: [
                    sourceTextureId0: MTLTextureCreator.makeBlankTexture(label: "sourceTexture0", with: device)!,
                    sourceTextureId1: MTLTextureCreator.makeBlankTexture(label: "sourceTexture1", with: device)!,
                    sourceTextureId2: MTLTextureCreator.makeBlankTexture(label: "sourceTexture2", with: device)!,
                    sourceTextureId3: MTLTextureCreator.makeBlankTexture(label: "sourceTexture3", with: device)!,
                    sourceTextureId4: MTLTextureCreator.makeBlankTexture(label: "sourceTexture4", with: device)!
                ]
            )

            let canvasRenderer = CanvasRenderer(
                renderer: mockRenderer
            )
            canvasRenderer.setTextureRepository(textureRepository)

            let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
            commandBuffer.label = "commandBuffer"

            let _ = canvasRenderer.mergeLayerTextures(
                layers: condition.textureLayers,
                into: destinationTexture,
                with: commandBuffer
            )
            .sink(
                receiveCompletion: { _ in
                    XCTAssertEqual(mockRenderer.callHistory, results.results)
                    mockRenderer.callHistory.removeAll()
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )

            wait(for: [expectation], timeout: 1.0)
        }
    }

}
