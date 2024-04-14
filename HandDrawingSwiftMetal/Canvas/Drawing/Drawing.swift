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

    func initDrawingIfHashValueIsNil(
        lineDrawing: DrawingLineProtocol,
        hashValue: TouchHashValue
    ) {
        if lineDrawing.hashValue == nil {
            lineDrawing.initDrawing(hashValue: hashValue)
        }
    }

    func makeLineSegment(
        from touchManager: TouchManager,
        with lineDrawing: DrawingLineProtocol,
        matrix: CGAffineTransform,
        parameters: LineParameters
    ) -> LineSegment? {
        guard
            let hashValue = lineDrawing.hashValue,
            let touchPhase = touchManager.getLatestTouchPhase(with: hashValue),
            let touchPoints = touchManager.getTouchPoints(with: hashValue)
        else { return nil }

        let isFingerReleasedFromScreen = touchPhase == .ended

        defer {
            if isFingerReleasedFromScreen {
                lineDrawing.finishDrawing()
            }
        }

        let diffCount = touchPoints.count - lineDrawing.iterator.array.count
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
        lineDrawing.appendToIterator(dotPoints)

        // It will be called when the drawing type is `SmoothLineDrawing`
        if let drawingLine = lineDrawing as? SmoothLineDrawing,
           isFingerReleasedFromScreen {
            drawingLine.appendLastTouchToSmoothCurveIterator()
        }

        let curvePoints = Curve.makePoints(
            from: lineDrawing.iterator,
            isFinishDrawing: isFingerReleasedFromScreen
        )

        return .init(
            dotPoints: curvePoints,
            parameters: parameters,
            touchPhase: touchPhase
        )
    }

    func addDrawLineSegmentCommands(
        with lineSegment: LineSegment,
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

    func addFinishDrawingCommands(
        on layerManager: LayerManager,
        to commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let commandBuffer,
            let drawingLayer = layerManager.drawingLayer,
            let selectedTexture = layerManager.selectedTexture
        else { return }

        drawingLayer.mergeDrawingTexture(
            into: selectedTexture,
            commandBuffer
        )
    }
}
