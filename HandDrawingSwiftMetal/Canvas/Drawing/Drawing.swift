//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import UIKit
import Combine

final class Drawing {

    var frameSize: CGSize = .zero {
        didSet {
            layerManager.frameSize = frameSize
        }
    }
    var textureSize: CGSize {
        textureSizeSubject.value
    }

    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> {
        matrixSubject.eraseToAnyPublisher()
    }

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> {
        addUndoObjectToUndoStackSubject.eraseToAnyPublisher()
    }

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

    var mergeAllLayersToRootTexturePublisher: AnyPublisher<Void, Never> {
        mergeAllLayersToRootTextureSubject.eraseToAnyPublisher()
    }

    var callSetNeedsDisplayOnCanvasViewPublisher: AnyPublisher<Void, Never> {
        callSetNeedsDisplayOnCanvasViewSubject.eraseToAnyPublisher()
    }

    var textureSizePublisher: AnyPublisher<CGSize, Never> {
        textureSizeSubject.eraseToAnyPublisher()
    }

    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let mergeAllLayersToRootTextureSubject = PassthroughSubject<Void, Never>()

    private let callSetNeedsDisplayOnCanvasViewSubject = PassthroughSubject<Void, Never>()

    private let textureSizeSubject = CurrentValueSubject<CGSize, Never>(.zero)

    /// An instance for managing texture layers
    let layerManager = LayerManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        layerManager.commitCommandToMergeAllLayersToRootTextureSubject
            .sink { [weak self] in
                self?.mergeAllLayersToRootTextureSubject.send()
                self?.callSetNeedsDisplayOnCanvasViewSubject.send()
            }
            .store(in: &cancellables)
    }

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
                frameSize: frameSize,
                textureSize: textureSize
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
              let drawingLayer = layerManager.drawingLayer
        else { return }

        if lineSegment.touchPhase == .ended {
            addUndoObjectToUndoStackSubject.send()
        }

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

        layerManager.addMergeAllLayersCommands(
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
                x: frameSize.width * 0.5,
                y: frameSize.height * 0.5
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

    func mergeAllLayersToRootTexture() {
        mergeAllLayersToRootTextureSubject.send()
    }
    func callSetNeedsDisplayOnCanvasView() {
        callSetNeedsDisplayOnCanvasViewSubject.send()
    }

    func setTextureSize(_ size: CGSize) {
        textureSizeSubject.send(size)
    }

    func initLayers(textureSize: CGSize) {
        layerManager.initLayers(textureSize)
    }

    func addMergeAllLayersCommands(
        backgroundColor: UIColor,
        onto dstTexture: MTLTexture?,
        to commandBuffer: MTLCommandBuffer
    ) {
        guard let dstTexture else { return }

        layerManager.addMergeAllLayersCommands(
            backgroundColor: backgroundColor,
            onto: dstTexture,
            to: commandBuffer
        )
    }

}
