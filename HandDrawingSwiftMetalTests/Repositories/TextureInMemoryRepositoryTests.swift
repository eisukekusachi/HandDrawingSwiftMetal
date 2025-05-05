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
            let isCanvasInitialized: Bool
            let isStorageInitialized: Bool
        }

        let testCases: [(Condition, Expectation)] = [
            (
                .init(
                    textures: [
                        UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!: nil,
                        UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!: nil
                    ],
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                ),
                .init(
                    isCanvasInitialized: true,
                    isStorageInitialized: false
                )
            ),
            (
                .init(
                    textures: [:],
                    layers: []
                ),
                .init(
                    isCanvasInitialized: false,
                    isStorageInitialized: true
                )
            ),
            (
                .init(
                    textures: [:],
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                ),
                .init(
                    isCanvasInitialized: false,
                    isStorageInitialized: true
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
                    isCanvasInitialized: false,
                    isStorageInitialized: true
                )
            )
        ]

        for testCase in testCases {
            let condition = testCase.0
            let expected = testCase.1

            let subject = TextureInMemoryRepository(textures: condition.textures)

            var isCanvasInitialized = false
            var isStorageInitialized = false

            var cancellables = Set<AnyCancellable>()

            let restoreExpectation = XCTestExpectation()
            let initializeExpectation = XCTestExpectation()

            // Invert expectations based on the expected outcome
            if !expected.isCanvasInitialized {
                restoreExpectation.isInverted = true
            }
            if !expected.isStorageInitialized {
                initializeExpectation.isInverted = true
            }

            subject.canvasInitializationUsingConfigurationPublisher
                .sink { _ in
                    isCanvasInitialized = true
                    restoreExpectation.fulfill()
                }
                .store(in: &cancellables)

            subject.storageInitializationWithNewTexturePublisher
                .sink { _ in
                    isStorageInitialized = true
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

            XCTAssertEqual(isCanvasInitialized, expected.isCanvasInitialized)
            XCTAssertEqual(isStorageInitialized, expected.isStorageInitialized)
        }
    }
}
