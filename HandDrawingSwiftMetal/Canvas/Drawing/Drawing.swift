//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import UIKit
import Combine

final class Drawing {

    /// An instance for managing texture layers
    let layerManager = LayerManager()

    var undoObject: UndoObject {
        return UndoObject(
            index: layerManager.index,
            layers: layerManager.layers
        )
    }

    var frameSize: CGSize = .zero {
        didSet {
            layerManager.frameSize = frameSize
        }
    }

    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> {
        matrixSubject.eraseToAnyPublisher()
    }

    var textureSize: CGSize {
        textureSizeSubject.value
    }

    var textureSizePublisher: AnyPublisher<CGSize, Never> {
        textureSizeSubject.eraseToAnyPublisher()
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

    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    private let textureSizeSubject = CurrentValueSubject<CGSize, Never>(.zero)

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let mergeAllLayersToRootTextureSubject = PassthroughSubject<Void, Never>()

    private let callSetNeedsDisplayOnCanvasViewSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init() {
        layerManager.addUndoObjectToUndoStackPublisher
            .subscribe(addUndoObjectToUndoStackSubject)
            .store(in: &cancellables)

        layerManager.mergeAllLayersToRootTexturePublisher
            .sink { [weak self] in
                self?.mergeAllLayersToRootTextureSubject.send()
                self?.callSetNeedsDisplayOnCanvasViewSubject.send()
            }
            .store(in: &cancellables)
    }

    func setDrawingTool(_ tool: DrawingToolType) {
        layerManager.setDrawingLayer(tool)
    }

    func setTextureSize(_ size: CGSize) {
        textureSizeSubject.send(size)
    }

    func callSetNeedsDisplayOnCanvasView() {
        callSetNeedsDisplayOnCanvasViewSubject.send()
    }

}

// MARK: - Drawing

extension Drawing {

    func makeLineSegment(
        from touchManager: TouchManager,
        with drawing: DrawingLineProtocol,
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
                matrix: matrixSubject.value,
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
        backgroundColor: UIColor,
        on rootTexture: MTLTexture?,
        to commandBuffer: MTLCommandBuffer?
    ) {
        guard let rootTexture,
              let commandBuffer,
              let drawingLayer = layerManager.drawingLayer
        else { return }

        let isFingerReleasedFromScreen = lineSegment.touchPhase == .ended

        if isFingerReleasedFromScreen {
            addUndoObjectToUndoStackSubject.send()
        }

        drawingLayer.drawOnDrawingTexture(
            segment: lineSegment,
            on: layerManager.selectedTexture,
            commandBuffer)

        if isFingerReleasedFromScreen,
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
            backgroundColor: backgroundColor,
            onto: rootTexture,
            to: commandBuffer)

        pauseDisplayLinkSubject.send(isFingerReleasedFromScreen)
    }

}

// MARK: - Transforming

extension Drawing {

    func setMatrix(_ matrix: CGAffineTransform) {
        matrixSubject.send(matrix)
    }

    func transformCanvas(
        _ touchManager: TouchManager,
        with transforming: TransformingProtocol
    ) {
        transforming.setHashValueIfNil(touchManager)

        transforming.updateTouches(touchManager)

        let isFingerReleasedFromScreen = touchManager.getTouchPhases(
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
            setMatrix(newMatrix)
        }

        pauseDisplayLinkSubject.send(isFingerReleasedFromScreen)
    }

}

// MARK: - Layer

extension Drawing {

    func setTextureSizeOfLayer(_ textureSize: CGSize) {
        layerManager.changeTextureSize(textureSize)
    }

    func setLayer(index: Int, layers: [LayerModel]) {
        layerManager.layers = layers
        layerManager.index = index
    }

    func resetLayer(with newTexture: MTLTexture) {
        let layerData = LayerModel.init(
            texture: newTexture,
            title: "NewLayer"
        )

        layerManager.layers.removeAll()
        layerManager.layers.append(layerData)
        layerManager.index = 0
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

    func mergeAllLayersToRootTexture() {
        mergeAllLayersToRootTextureSubject.send()
    }

}
