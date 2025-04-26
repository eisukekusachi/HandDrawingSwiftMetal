//
//  TextureInMemoryRepositoryTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/26.
//

import Combine
import XCTest
@testable import HandDrawingSwiftMetal

final class TextureInMemoryRepositoryTests: XCTestCase {
    /// Confirms whether to initialize or restore based on the states of the textures and the model
    func testResolveCanvasView() async {
        struct Condition {
            let textures: [UUID: MTLTexture?]
            let layers: [TextureLayerModel]
        }
        struct Expectation {
            let isRestoredFromModel: Bool
            let isInitializedAfterNewTextureCreation: Bool
        }

        let testCases: [(Condition, Expectation)] = [
            (
                .init(
                    textures: [
                        UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!: nil,
                        UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!: nil
                    ],
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!)
                    ]
                ),
                .init(
                    isRestoredFromModel: true,
                    isInitializedAfterNewTextureCreation: false
                )
            ),
            (
                .init(
                    textures: [:],
                    layers: []
                ),
                .init(
                    isRestoredFromModel: false,
                    isInitializedAfterNewTextureCreation: true
                )
            ),
            (
                .init(
                    textures: [:],
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!)
                    ]
                ),
                .init(
                    isRestoredFromModel: false,
                    isInitializedAfterNewTextureCreation: true
                )
            ),
            (
                .init(
                    textures: [
                        UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!: nil,
                        UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!: nil
                    ],
                    layers: []
                ),
                .init(
                    isRestoredFromModel: false,
                    isInitializedAfterNewTextureCreation: true
                )
            )
        ]

        for testCase in testCases {
            let condition = testCase.0
            let expected = testCase.1

            let subject = TextureInMemoryRepository(textures: condition.textures)

            var restoreCanvasFromModelCalled = false
            var initializeCanvasFromModelAfterNewTextureCreationCalled = false

            var cancellables = Set<AnyCancellable>()

            let restoreExpectation = XCTestExpectation()
            let initializeExpectation = XCTestExpectation()

            // Invert expectations based on the expected outcome
            if !expected.isRestoredFromModel {
                restoreExpectation.isInverted = true
            }
            if !expected.isInitializedAfterNewTextureCreation {
                initializeExpectation.isInverted = true
            }

            subject.restoreCanvasFromModelPublisher
                .sink { _ in
                    restoreCanvasFromModelCalled = true
                    restoreExpectation.fulfill()
                }
                .store(in: &cancellables)

            subject.initializeCanvasAfterCreatingNewTexturePublisher
                .sink { _ in
                    initializeCanvasFromModelAfterNewTextureCreationCalled = true
                    initializeExpectation.fulfill()
                }
                .store(in: &cancellables)

            /// If all layer IDs in the `CanvasModel` have matching texture IDs in the `TextureRepository`,
            /// the canvas will be restored using that model.
            /// Otherwise, a new texture will be created and the canvas will be initialized.
            subject.resolveCanvasView(
                from: .init(layers: condition.layers),
                drawableSize: .init(width: 44, height: 44)
            )

            await fulfillment(of: [restoreExpectation, initializeExpectation], timeout: 1.0)

            XCTAssertEqual(restoreCanvasFromModelCalled, expected.isRestoredFromModel)
            XCTAssertEqual(initializeCanvasFromModelAfterNewTextureCreationCalled, expected.isInitializedAfterNewTextureCreation)
        }
    }
}
