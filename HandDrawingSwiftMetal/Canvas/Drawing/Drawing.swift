//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import UIKit
import Combine

final class Drawing {

    var frameSize: CGSize = .zero
    var textureSize: CGSize = .zero

    func makeLineSegment(
        from touchManager: TouchManager,
        with drawing: DrawingLineProtocol,
        matrix: CGAffineTransform,
        parameters: LineParameters
    ) -> LineSegment? {

        drawing.setHashValueIfNil(touchManager)

        guard
            let hashValue = drawing.hashValue,
            let touchPhase = touchManager.getLatestTouchPhase(with: hashValue),
            let touchPoints = touchManager.getTouchPoints(with: hashValue)
        else { return nil }

        let isFingerReleasedFromScreen = touchPhase == .ended

        defer {
            if isFingerReleasedFromScreen {
                drawing.clear()
            }
        }

        let diffCount = touchPoints.count - drawing.iterator.array.count
        guard diffCount > 0 else { return nil }

        let newTouchPoints = touchPoints.suffix(diffCount)

        let dotPoints = newTouchPoints.map {
            DotPoint(
                touchPoint: $0,
                matrix: matrix,
                frameSize: frameSize,
                textureSize: textureSize
            )
        }
        drawing.appendToIterator(dotPoints)

        if isFingerReleasedFromScreen, let drawing = drawing as? SmoothLineDrawing {
            drawing.appendLastTouchToSmoothCurveIterator()
        }

        let curvePoints = Curve.makePoints(
            from: drawing.iterator,
            isFinishDrawing: isFingerReleasedFromScreen
        )

        return .init(
            dotPoints: curvePoints,
            parameters: parameters,
            touchPhase: touchPhase
        )
    }

    func addDrawSegmentCommands(
        _ lineSegment: LineSegment,
        on layerManager: LayerManager,
        to commandBuffer: MTLCommandBuffer?
    ) {
        guard 
            let commandBuffer,
            let drawingLayer = layerManager.drawingLayer
        else { return }

        drawingLayer.drawOnDrawingTexture(
            segment: lineSegment,
            on: layerManager.selectedTexture,
            commandBuffer)

        if lineSegment.touchPhase == .ended,
           let selectedTexture = layerManager.selectedTexture {

            drawingLayer.mergeDrawingTexture(
                into: selectedTexture,
                commandBuffer
            )

            Task {
                try? await layerManager.updateCurrentThumbnail()
            }
        }
    }

}
