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
    /// Confirms whether to initialize or restore based on the states of the textures and the configuration
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
            var initializeCanvasWithNewTextureCalled = false

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

            subject.storageInitializationUsingConfigurationPublisher
                .sink { _ in
                    restoreCanvasFromModelCalled = true
                    restoreExpectation.fulfill()
                }
                .store(in: &cancellables)

            subject.storageInitializationWithNewTexturePublisher
                .sink { _ in
                    initializeCanvasWithNewTextureCalled = true
                    initializeExpectation.fulfill()
                }
                .store(in: &cancellables)

            /// If all layer IDs in the `CanvasConfiguration` have matching texture IDs in the `TextureRepository`,
            /// the storage will be restored using that configuration.
            /// Otherwise, a new texture will be created and the storage will be initialized.
            subject.initializeStorage(
                from: .init(layers: condition.layers)
            )

            await fulfillment(of: [restoreExpectation, initializeExpectation], timeout: 1.0)

            XCTAssertEqual(restoreCanvasFromModelCalled, expected.isRestoredFromModel)
            XCTAssertEqual(initializeCanvasWithNewTextureCalled, expected.isInitializedAfterNewTextureCreation)
        }
    }
}
