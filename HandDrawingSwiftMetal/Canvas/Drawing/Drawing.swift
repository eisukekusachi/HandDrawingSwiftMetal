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

    // TODO: Remove this property
    var textureSize: CGSize = .zero

    func initDrawingIfHashValueIsNil(
        lineDrawing: DrawingLineProtocol,
        hashValue: TouchHashValue
    ) {
        if lineDrawing.hashValue == nil {
            lineDrawing.initDrawing(hashValue: hashValue)
        }
    }

    func getNewTouchPoints(
        from touchManager: TouchManager,
        with lineDrawing: DrawingLineProtocol
    ) -> [TouchPoint] {
        guard
            let hashValue = lineDrawing.hashValue,
            let touchPoints = touchManager.getTouchPoints(with: hashValue)
        else { return [] }

        let diffCount = touchPoints.count - lineDrawing.iterator.array.count
        guard diffCount > 0 else { return [] }

        return touchPoints.suffix(diffCount)
    }

    func makeLineSegment(
        from iterator: Iterator<DotPoint>,
        with parameters: LineParameters,
        touchPhase: UITouch.Phase
    ) -> LineSegment {
        .init(
            dotPoints: Curve.makePoints(
                from: iterator,
                isFinishDrawing: touchPhase == .ended
            ),
            parameters: parameters,
            touchPhase: touchPhase
        )
    }

    func addDrawLineSegmentCommands(
        with lineSegment: LineSegment,
        on layerManager: ImageLayerManager,
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
        }
    }

    func addFinishDrawingCommands(
        on layerManager: ImageLayerManager,
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
