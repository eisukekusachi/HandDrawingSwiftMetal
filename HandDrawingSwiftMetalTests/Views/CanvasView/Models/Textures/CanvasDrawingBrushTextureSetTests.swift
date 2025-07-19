//
//  DrawingBrushTextureSetTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Combine
@testable import HandDrawingSwiftMetal

final class DrawingBrushTextureSetTests: XCTestCase {

    var subject: DrawingBrushTextureSet!

    var commandBuffer: MTLCommandBuffer!
    let device = MTLCreateSystemDefaultDevice()!

    var baseTexture: MTLTexture!

    var renderer = MockMTLRenderer()

    var cancellables = Set<AnyCancellable>()

    let drawingTextureLabel = "drawingTexture"
    let grayscaleTextureLabel = "grayscaleTexture"
    let realtimeDrawingTextureLabel = "realtimeDrawingTexture"
    let baseTextureLabel = "baseTexture"
    let commandBufferLabel = "commandBuffer"

    override func setUp() {
        commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        commandBuffer.label = commandBufferLabel

        subject = DrawingBrushTextureSet(renderer: renderer)
        subject.initTextures(.init(width: 1, height: 1))
        subject.setBrushColor(.red)

        renderer.callHistory.removeAll()

        baseTexture = MTLTextureCreator.makeBlankTexture(
            size: .init(width: MTLRenderer.threadGroupLength, height: MTLRenderer.threadGroupLength),
            with: device
        )!
        baseTexture.label = baseTextureLabel
    }

    /// Confirms the process in which the brush curve is drawn on `realtimeDrawingTexture` using `baseTextureLabel`
    func testDrawBrushCurvePoints() {

        struct Condition: Hashable {
            let touchPhase: UITouch.Phase
        }

        struct Expectation {
            let result: [String]
            let isDrawingFinished: Bool
        }

        // Draw the point buffers in opaque grayscale with the max blend mode on `grayscaleTexture`.
        // Apply the specified color to `grayscaleTexture` and draw it onto `drawingTexture`.
        // Composite `baseTexture` onto `realtimeDrawingTexture` as the background.
        // Merge `drawingTexture` onto `realtimeDrawingTexture` to produce the final drawing state.
        let drawingCurve: [String] = [
            "drawGrayPointBuffersWithMaxBlendMode(buffers: buffers, onGrayscaleTexture: \(grayscaleTextureLabel), with: \(commandBufferLabel))",
            "drawTexture(grayscaleTexture: \(grayscaleTextureLabel), color: (255, 0, 0), on: \(drawingTextureLabel), with: \(commandBufferLabel))",
            "drawTexture(texture: \(baseTextureLabel), buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: \(realtimeDrawingTextureLabel), with: \(commandBufferLabel))",
            "mergeTexture(texture: \(drawingTextureLabel), into: \(realtimeDrawingTextureLabel), with: \(commandBufferLabel))"
        ]

        // Draw `realtimeDrawingTexture` on `baseTexture`.
        // Clear the textures used for drawing to prepare for the next drawing.
        let drawingCompletionProcess: [String] = [
            "drawTexture(texture: \(realtimeDrawingTextureLabel), buffers: buffers, withBackgroundColor: (0, 0, 0, 0), on: \(baseTextureLabel), with: \(commandBufferLabel))",
            "clearTextures(textures: [\(drawingTextureLabel), \(grayscaleTextureLabel)], with: \(commandBufferLabel))"
        ]

        let testCases: [Condition: Expectation] = [
            .init(touchPhase: .began): .init(result: drawingCurve, isDrawingFinished: false),
            .init(touchPhase: .moved): .init(result: drawingCurve, isDrawingFinished: false),
            .init(touchPhase: .ended): .init(result: drawingCurve + drawingCompletionProcess, isDrawingFinished: true),
            .init(touchPhase: .cancelled): .init(result: drawingCurve + drawingCompletionProcess, isDrawingFinished: true)
        ]

        testCases.forEach { testCase in
            let iterator = MockDrawingCurve()

            iterator.touchPhase.send(testCase.key.touchPhase)

            var didCallDrawingCompleted = false

            subject.updateRealTimeDrawingTexture(
                baseTexture: baseTexture,
                drawingCurve: iterator,
                with: commandBuffer,
                onDrawing: { _ in

                },
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
