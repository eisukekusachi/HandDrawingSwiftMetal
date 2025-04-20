//
//  TextureLayersTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/07.
//

import Combine
import XCTest
@testable import HandDrawingSwiftMetal

final class TextureLayersTests: XCTestCase {

    func testRestoreLayers() async {
        struct Condition {
            let layers: [TextureLayerModel]
        }
        struct Expectation {
            let isInitializedUsingModel: Bool
        }

        /// Restoration using CanvasModel is performed only when the array of TextureLayerModel IDs in the CanvasModel
        /// exactly matches the array of texture IDs in the TextureRepository in both content and count.
        /// Otherwise, initialization falls back to using the texture size.
        let testCases: [(Condition, Expectation)] = [
            (
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                ),
                .init(isInitializedUsingModel: true)
            ),
            (
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!, title: ""),
                        .init(id: UUID(uuidString: "00000002-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                ),
                .init(isInitializedUsingModel: false)
            ),
            (
                .init(
                    layers: [
                        .init(id: UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!, title: "")
                    ]
                ),
                .init(isInitializedUsingModel: false)
            ),
            (
                .init(layers: []),
                .init(isInitializedUsingModel: false)
            )
        ]

        for testCase in testCases {
            let condition = testCase.0
            let result = testCase.1

            let subject = TextureLayers(
                canvasState: .init(CanvasModel()),
                textureRepository: TextureInMemoryRepository(
                    textures: [
                        UUID(uuidString: "00000000-1234-4abc-8def-1234567890ab")!: nil,
                        UUID(uuidString: "00000001-1234-4abc-8def-1234567890ab")!: nil
                    ]
                )
            )

            var usingCanvasModelPublisherCalled = false
            var usingTextureSizePublisherCalled = false

            let expectation = XCTestExpectation()

            var cancellables = Set<AnyCancellable>()

            subject.initializeCanvasWithModelPublisher
                .sink { _ in
                    usingCanvasModelPublisherCalled = true
                    expectation.fulfill()
                }
                .store(in: &cancellables)

            subject.initializeWithTextureSizePublisher
                .sink { _ in
                    usingTextureSizePublisherCalled = true
                    expectation.fulfill()
                }
                .store(in: &cancellables)

            subject.restoreLayers(
                from: .init(layers: condition.layers),
                drawableSize: .zero
            )

            await fulfillment(of: [expectation], timeout: 1.0)

            XCTAssertEqual(usingCanvasModelPublisherCalled, result.isInitializedUsingModel)
            XCTAssertEqual(usingTextureSizePublisherCalled, !result.isInitializedUsingModel)
        }
    }

}
