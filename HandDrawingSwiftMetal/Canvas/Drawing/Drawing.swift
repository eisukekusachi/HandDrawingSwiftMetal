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

        // When a gesture is determined to be `drawing`, the touchManager manages only one finger
        if drawing.hashValue == nil,
           let hashValue = touchManager.touchPointsDictionary.keys.first {
            drawing.initDrawing(hashValue: hashValue)
        }

        guard
            let hashValue = drawing.hashValue,
            let touchPhase = touchManager.getLatestTouchPhase(with: hashValue),
            let touchPoints = touchManager.getTouchPoints(with: hashValue)
        else { return nil }

        let isFingerReleasedFromScreen = touchPhase == .ended

        defer {
            if isFingerReleasedFromScreen {
                drawing.finishDrawing()
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

        // It will be called when the drawing type is `SmoothLineDrawing`
        if let drawing = drawing as? SmoothLineDrawing,
           isFingerReleasedFromScreen {
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
            let drawingLayer = layerManager.drawingLayer,
            let selectedTexture = layerManager.selectedTexture
        else { return }

        if let drawingLayer = drawingLayer as? DrawingEraserLayer {
            drawingLayer.drawOnDrawingTexture(
                segment: lineSegment,
                srcTexture: selectedTexture,
                commandBuffer)

        } else if let drawingLayer = drawingLayer as? DrawingBrushLayer {
            drawingLayer.drawOnDrawingTexture(
                segment: lineSegment,
                commandBuffer)
        }

        if lineSegment.touchPhase == .ended {

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
