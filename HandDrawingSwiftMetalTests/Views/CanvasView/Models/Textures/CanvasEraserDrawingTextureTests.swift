//
//  CanvasEraserDrawingTextureTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Combine
@testable import HandDrawingSwiftMetal

final class CanvasEraserDrawingTextureTests: XCTestCase {

    var subject: CanvasEraserDrawingTexture!

    var commandBuffer: MTLCommandBuffer!
    let device = MTLCreateSystemDefaultDevice()!

    var sourceTexture: MTLTexture!
    var destinationTexture: MTLTexture!

    var renderer = MockMTLRenderer()

    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = "commandBuffer"

        subject = CanvasEraserDrawingTexture(renderer: renderer)
        subject.initTextures(.init(width: 1, height: 1))
        renderer.callHistory.removeAll()

        sourceTexture = MTLTextureCreator.makeBlankTexture(
            size: .init(width: MTLRenderer.threadGroupLength, height: MTLRenderer.threadGroupLength),
            with: device
        )!
        sourceTexture.label = "sourceTexture"

        destinationTexture = MTLTextureCreator.makeBlankTexture(
            size: .init(width: MTLRenderer.threadGroupLength, height: MTLRenderer.threadGroupLength),
            with: device
        )!
        destinationTexture.label = "destinationTexture"
    }

    /// Confirms the process in which the eraser curve is drawn on the destination texture using the source texture
    func testDrawEraserCurveUsingSelectedTexture() {

        struct Condition: Hashable {
            let touchPhase: UITouch.Phase
        }
        struct Expectation {
            let result: [String]
            let isDrawingFinished: Bool
        }

        // Draw the point buffers in opaque grayscale with the max blend mode on `grayscaleTexture`.
        // Draw `grayscaleTexture` with black applied on `lineDrawnTexture`.
        // Then, draw `sourceTexture` on `drawingTexture`.
        // Subtract `lineDrawnTexture` from `drawingTexture` in eraser mode.
        let drawingCurve: [String] = [
            "drawGrayPointBuffersWithMaxBlendMode(buffers: buffers, onGrayscaleTexture: grayscaleTexture, with: commandBuffer)",
            "drawTexture(grayscaleTexture: grayscaleTexture, color: (0, 0, 0), on: lineDrawnTexture, with: commandBuffer)",
            "drawTexture(texture: sourceTexture, buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: drawingTexture, with: commandBuffer)",
            "subtractTextureWithEraseBlendMode(texture: lineDrawnTexture, buffers: buffers, from: drawingTexture, with: commandBuffer)"
        ]

        // Draw `drawingTexture` on `destinationTexture`
        let drawingTexture: [String] = [
            "drawTexture(texture: drawingTexture, buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: destinationTexture, with: commandBuffer)"
        ]

        // Draw `sourceTexture` on `drawingTexture`.
        // Subtract `lineDrawnTexture` from `drawingTexture` in eraser mode.
        // Then, draw `drawingTexture` on `sourceTexture`.
        // Clear the textures used for drawing to prepare for the next drawing.
        let drawingCompletionProcess: [String] = [
            "drawTexture(texture: sourceTexture, buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: drawingTexture, with: commandBuffer)",
            "subtractTextureWithEraseBlendMode(texture: lineDrawnTexture, buffers: buffers, from: drawingTexture, with: commandBuffer)",
            "drawTexture(texture: drawingTexture, buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: sourceTexture, with: commandBuffer)",
            "clearTextures(textures: [drawingTexture, grayscaleTexture, lineDrawnTexture], with: commandBuffer)"
        ]

        let testCases: [Condition: Expectation] = [
            .init(touchPhase: .began): .init(result: drawingCurve + drawingTexture, isDrawingFinished: false),
            .init(touchPhase: .moved): .init(result: drawingCurve + drawingTexture, isDrawingFinished: false),
            .init(touchPhase: .ended): .init(result: drawingCurve + drawingTexture + drawingCompletionProcess, isDrawingFinished: true),
            .init(touchPhase: .cancelled): .init(result: drawingCurve + drawingTexture + drawingCompletionProcess, isDrawingFinished: true)
        ]

        testCases.forEach { testCase in
            let drawingIterator = MockDrawingCurveIterator()

            drawingIterator.currentTouchPhase = testCase.key.touchPhase

            let publisherExpectation = XCTestExpectation()
            if !testCase.value.isDrawingFinished {
                publisherExpectation.isInverted = true
            }

            // Confirm that `canvasDrawFinishedPublisher` emits `Void` at the end of the drawing process
            subject.canvasDrawFinishedPublisher
                .sink {
                    publisherExpectation.fulfill()
                }
                .store(in: &cancellables)

            subject.drawCurvePointsUsingSelectedTexture(
                drawingCurvePoints: drawingIterator,
                selectedTexture: sourceTexture,
                on: destinationTexture,
                with: commandBuffer
            )

            XCTAssertEqual(renderer.callHistory, testCase.value.result)
            renderer.callHistory.removeAll()

            wait(for: [publisherExpectation], timeout: 1.0)
        }
    }

}
