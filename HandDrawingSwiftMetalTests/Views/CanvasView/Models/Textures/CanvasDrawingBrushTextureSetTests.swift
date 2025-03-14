//
//  CanvasDrawingBrushTextureSetTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Combine
@testable import HandDrawingSwiftMetal

final class CanvasDrawingBrushTextureSetTests: XCTestCase {

    var subject: CanvasDrawingBrushTextureSet!

    var commandBuffer: MTLCommandBuffer!
    let device = MTLCreateSystemDefaultDevice()!

    var backgroundTexture: MTLTexture!
    var destinationTexture: MTLTexture!

    var renderer = MockMTLRenderer()

    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = "commandBuffer"

        subject = CanvasDrawingBrushTextureSet(renderer: renderer)
        subject.initTextures(.init(width: 1, height: 1))
        renderer.callHistory.removeAll()

        backgroundTexture = MTLTextureCreator.makeBlankTexture(
            size: .init(width: MTLRenderer.threadGroupLength, height: MTLRenderer.threadGroupLength),
            with: device
        )!
        backgroundTexture.label = "backgroundTexture"

        destinationTexture = MTLTextureCreator.makeBlankTexture(
            size: .init(width: MTLRenderer.threadGroupLength, height: MTLRenderer.threadGroupLength),
            with: device
        )!
        destinationTexture.label = "destinationTexture"
    }

    /// Confirms the process in which the brush curve is drawn on the destination texture using `backgroundTexture`
    func testDrawBrushCurvePoints() {

        struct Condition: Hashable {
            let touchPhase: UITouch.Phase
        }
        struct Expectation {
            let result: [String]
            let isDrawingFinished: Bool
        }

        // Draw the point buffers in opaque grayscale with the max blend mode on grayscaleTexture.
        // Draw the color-applied `grayscaleTexture` on `drawingTexture`.
        let drawingCurve: [String] = [
            "drawGrayPointBuffersWithMaxBlendMode(buffers: buffers, onGrayscaleTexture: grayscaleTexture, with: commandBuffer)",
            "drawTexture(grayscaleTexture: grayscaleTexture, color: (255, 0, 0), on: drawingTexture, with: commandBuffer)"
        ]

        // `backgroundTexture` and `drawingTexture` are layered and drawn on `destinationTexture`.
        let drawingTexture: [String] = [
            "drawTexture(texture: backgroundTexture, buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: destinationTexture, with: commandBuffer)",
            "mergeTexture(texture: drawingTexture, alpha: 255, maskTexture: maskTexture, into: destinationTexture, with: commandBuffer)"
        ]

        // Merge `drawingTexture` on `backgroundTexture`.
        // Clear the textures used for drawing to prepare for the next drawing.
        let drawingCompletionProcess: [String] = [
            "mergeTexture(texture: drawingTexture, alpha: 255, maskTexture: maskTexture, into: backgroundTexture, with: commandBuffer)",
            "clearTextures(textures: [drawingTexture, grayscaleTexture], with: commandBuffer)"
        ]

        let testCases: [Condition: Expectation] = [
            .init(touchPhase: .began): .init(result: drawingCurve + drawingTexture, isDrawingFinished: false),
            .init(touchPhase: .moved): .init(result: drawingCurve + drawingTexture, isDrawingFinished: false),
            .init(touchPhase: .ended): .init(result: drawingCurve + drawingTexture + drawingCompletionProcess, isDrawingFinished: true),
            .init(touchPhase: .cancelled): .init(result: drawingCurve + drawingTexture + drawingCompletionProcess, isDrawingFinished: true)
        ]

        testCases.forEach { testCase in
            let drawingIterator = MockDrawingCurveIterator()

            drawingIterator.touchPhase = testCase.key.touchPhase

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

            subject.setBlushColor(.red)

            subject.drawCurvePoints(
                drawingCurveIterator: drawingIterator,
                withBackgroundTexture: backgroundTexture,
                withBackgroundColor: .clear,
                on: destinationTexture,
                with: commandBuffer
            )

            XCTAssertEqual(renderer.callHistory, testCase.value.result)
            renderer.callHistory.removeAll()

            wait(for: [publisherExpectation], timeout: 1.0)
        }
    }

}
