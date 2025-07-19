//
//  CanvasDrawingEraserTextureSetTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Combine
@testable import HandDrawingSwiftMetal

final class CanvasDrawingEraserTextureSetTests: XCTestCase {

    var subject: CanvasDrawingEraserTextureSet!

    var commandBuffer: MTLCommandBuffer!
    let device = MTLCreateSystemDefaultDevice()!

    var baseTexture: MTLTexture!

    var renderer = MockMTLRenderer()

    var cancellables = Set<AnyCancellable>()

    let drawingTextureLabel = "drawingTexture"
    let grayscaleTextureLabel = "grayscaleTexture"
    let lineDrawnTextureLabel = "lineDrawnTexture"
    let realtimeDrawingTextureLabel = "realtimeDrawingTexture"
    let baseTextureLabel = "baseTexture"
    let commandBufferLabel = "commandBuffer"

    override func setUp() {
        commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = commandBufferLabel

        subject = CanvasDrawingEraserTextureSet(renderer: renderer)
        subject.initTextures(.init(width: 1, height: 1))
        renderer.callHistory.removeAll()

        baseTexture = MTLTextureCreator.makeBlankTexture(
            size: .init(width: MTLRenderer.threadGroupLength, height: MTLRenderer.threadGroupLength),
            with: device
        )!
        baseTexture.label = baseTextureLabel
    }

    /// Confirms the process in which the eraser curve is drawn on `realtimeDrawingTexture` using `baseTexture`
    func testDrawEraserCurvePoints() {

        struct Condition: Hashable {
            let touchPhase: UITouch.Phase
        }
        struct Expectation {
            let result: [String]
            let isDrawingFinished: Bool
        }

        // Render the point buffers in opaque grayscale with the max blend mode onto `grayscaleTexture`.
        // Apply black to `grayscaleTexture` and draw it onto `lineDrawnTexture`.
        // Composite `baseTexture` onto `drawingTexture` as the background.
        // Subtract `lineDrawnTexture` from `drawingTexture` in eraser mode.
        // Draw the updated `drawingTexture` onto `realtimeDrawingTexture` to produce the current frame.
        let drawingCurve: [String] = [
            "drawGrayPointBuffersWithMaxBlendMode(buffers: buffers, onGrayscaleTexture: grayscaleTexture, with: \(commandBufferLabel))",
            "drawTexture(grayscaleTexture: \(grayscaleTextureLabel), color: (0, 0, 0), on: \(lineDrawnTextureLabel), with: \(commandBufferLabel))",
            "drawTexture(texture: \(baseTextureLabel), buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: drawingTexture, with: \(commandBufferLabel))",
            "subtractTextureWithEraseBlendMode(texture: \(lineDrawnTextureLabel), buffers: buffers, from: \(drawingTextureLabel), with: \(commandBufferLabel))",
            "drawTexture(texture: \(drawingTextureLabel), buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: \(realtimeDrawingTextureLabel), with: \(commandBufferLabel))"
        ]

        // Draw `realtimeDrawingTexture` on `baseTexture`.
        // Clear the textures used for drawing to prepare for the next drawing.
        let drawingCompletionProcess: [String] = [
            "drawTexture(texture: \(realtimeDrawingTextureLabel), buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: \(baseTextureLabel), with: \(commandBufferLabel))",
            "clearTextures(textures: [\(drawingTextureLabel), \(grayscaleTextureLabel), \(lineDrawnTextureLabel)], with: \(commandBufferLabel))"
        ]

        let testCases: [Condition: Expectation] = [
            .init(touchPhase: .began): .init(result: drawingCurve, isDrawingFinished: false),
            .init(touchPhase: .moved): .init(result: drawingCurve, isDrawingFinished: false),
            .init(touchPhase: .ended): .init(result: drawingCurve + drawingCompletionProcess, isDrawingFinished: true),
            .init(touchPhase: .cancelled): .init(result: drawingCurve + drawingCompletionProcess, isDrawingFinished: true)
        ]

        testCases.forEach { testCase in
            let drawingCurve = MockDrawingCurve()

            drawingCurve.touchPhase.send(testCase.key.touchPhase)

            var didCallDrawingCompleted = false

            subject.updateRealTimeDrawingTexture(
                baseTexture: baseTexture,
                drawingCurve: drawingCurve,
                with: commandBuffer,
                onDrawingCompleted: { _ in
                    didCallDrawingCompleted = true
                }
            )

            XCTAssertEqual(renderer.callHistory, testCase.value.result)
            renderer.callHistory.removeAll()

            XCTAssertEqual(didCallDrawingCompleted, testCase.value.isDrawingFinished)
        }
    }

}
