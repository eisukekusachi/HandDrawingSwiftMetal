//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import UIKit
import Combine

final class Drawing {

    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> {
        matrixSubject.eraseToAnyPublisher()
    }

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> {
        addUndoObjectToUndoStackSubject.eraseToAnyPublisher()
    }

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    func makeLineSegment(
        _ touchManager: TouchManager,
        with drawing: DrawingLineProtocol,
        drawingTool: DrawingToolModel
    ) -> LineSegment? {

        drawing.setHashValueIfNil(touchManager)

        guard
            let hashValue = drawing.hashValue,
            let touchPhase = touchManager.getLatestTouchPhase(with: hashValue),
            let touchPoints = touchManager.getTouchPoints(with: hashValue)
        else { return nil }

        defer {
            if touchPhase == .ended {
                drawing.clear()
            }
        }

        let diffCount = touchPoints.count - drawing.iterator.array.count
        guard diffCount > 0 else { return nil }

        let newTouchPoints = touchPoints.suffix(diffCount)

        let dotPoints = newTouchPoints.map {
            DotPoint(
                touchPoint: $0,
                matrix: matrixSubject.value,
                frameSize: drawingTool.frameSize,
                textureSize: drawingTool.textureSize
            )
        }
        drawing.appendToIterator(dotPoints)

        if touchPhase == .ended, let drawing = drawing as? SmoothLineDrawing {
            drawing.appendLastTouchToSmoothCurveIterator()
        }

        let curvePoints = Curve.makePoints(
            from: drawing.iterator,
            isFinishDrawing: touchPhase == .ended
        )

        return .init(
            dotPoints: curvePoints,
            parameters: .init(drawingTool),
            touchPhase: touchPhase
        )
    }

    func drawSegmentOnTexture(
        _ lineSegment: LineSegment,
        _ drawingTool: DrawingToolModel,
        _ rootTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer?
    ) {
        guard let rootTexture,
              let commandBuffer,
              let drawingLayer = drawingTool.layerManager.drawingLayer
        else { return }

        if lineSegment.touchPhase == .ended {
            addUndoObjectToUndoStackSubject.send()
        }

        drawingLayer.drawOnDrawingTexture(
            segment: lineSegment,
            on: drawingTool.layerManager.selectedTexture,
            commandBuffer)

        if lineSegment.touchPhase == .ended,
           let selectedTexture = drawingTool.layerManager.selectedTexture {

            drawingLayer.mergeDrawingTexture(
                into: selectedTexture,
                commandBuffer
            )

            Task {
                try? await drawingTool.layerManager.updateCurrentThumbnail()
            }
        }

        drawingTool.layerManager.addMergeAllLayersCommands(
            backgroundColor: drawingTool.backgroundColor,
            onto: rootTexture,
            to: commandBuffer)

        pauseDisplayLinkSubject.send(lineSegment.touchPhase == .ended)
    }

    func transformCanvas(
        touchPointData: TouchManager,
        transforming: TransformingProtocol,
        drawingTool: DrawingToolModel) {

        transforming.setHashValueIfNil(touchPointData)

        transforming.updateTouches(touchPointData)

        let isFingerReleasedFromScreen = touchPointData.getTouchPhases(
            transforming.hashValues
        ).contains(.ended)

        if let matrix = transforming.makeMatrix(
            frameCenter: CGPoint(
                x: drawingTool.frameSize.width * 0.5,
                y: drawingTool.frameSize.height * 0.5
            )
        ) {
            let newMatrix = transforming.getMatrix(matrix)

            if isFingerReleasedFromScreen {
                transforming.updateMatrix(newMatrix)
                transforming.clear()
            }
            matrixSubject.send(newMatrix)
        }

        pauseDisplayLinkSubject.send(isFingerReleasedFromScreen)
    }

    func setMatrix(_ matrix: CGAffineTransform) {
        matrixSubject.send(matrix)
    }

}
