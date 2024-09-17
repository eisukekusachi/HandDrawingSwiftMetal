//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

final class CanvasViewModel {

    let canvasTransformer = CanvasTransformer()

    let textureLayers = TextureLayers()

    let textureLayerUndoManager = TextureLayerUndoManager()

    let drawingTool = CanvasDrawingToolStatus()

    var frameSize: CGSize = .zero

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

    var requestShowingActivityIndicatorPublisher: AnyPublisher<Bool, Never> {
        requestShowingActivityIndicatorSubject.eraseToAnyPublisher()
    }

    var requestShowingAlertPublisher: AnyPublisher<String, Never> {
        requestShowingAlertSubject.eraseToAnyPublisher()
    }

    var requestShowingToastPublisher: AnyPublisher<ToastModel, Never> {
        requestShowingToastSubject.eraseToAnyPublisher()
    }

    var requestShowingLayerViewPublisher: AnyPublisher<Bool, Never> {
        requestShowingLayerViewSubject.eraseToAnyPublisher()
    }

    var refreshCanvasPublisher: AnyPublisher<CanvasModel, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }

    var refreshCanvasWithUndoObjectPublisher: AnyPublisher<TextureLayerUndoObject, Never> {
        refreshCanvasWithUndoObjectSubject.eraseToAnyPublisher()
    }

    var refreshCanUndoPublisher: AnyPublisher<Bool, Never> {
        refreshCanUndoSubject.eraseToAnyPublisher()
    }
    var refreshCanRedoPublisher: AnyPublisher<Bool, Never> {
        refreshCanRedoSubject.eraseToAnyPublisher()
    }

    /// An iterator for managing a grayscale curve
    private var grayscaleTextureCurveIterator: CanvasGrayscaleCurveIterator?

    private let fingerScreenTouchManager = CanvasFingerScreenTouchPoints()

    /// A manager for handling Apple Pencil input values
    private let pencilScreenTouchPoints = CanvasPencilScreenTouchPoints()

    private let inputDevice = CanvasInputDeviceStatus()

    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private var localRepository: LocalRepository?

    /// A texture with a background color, composed of `drawingTexture` and `currentTexture`
    private var canvasTexture: MTLTexture?
    /// A texture that combines the texture of the currently selected `TextureLayer` and `DrawingTexture`
    private let currentTexture = CanvasCurrentTexture()
    /// A protocol for managing current drawing texture
    private (set) var drawingTexture: CanvasDrawingTextureProtocol?
    /// A drawing texture with a brush
    private let brushDrawingTexture = CanvasBrushDrawingTexture()
    /// A drawing texture with an eraser
    private let eraserDrawingTexture = CanvasEraserDrawingTexture()

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let requestShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private let refreshCanvasSubject = PassthroughSubject<CanvasModel, Never>()

    private let refreshCanvasWithUndoObjectSubject = PassthroughSubject<TextureLayerUndoObject, Never>()

    private let refreshCanUndoSubject = PassthroughSubject<Bool, Never>()

    private let refreshCanRedoSubject = PassthroughSubject<Bool, Never>()

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()

    init(
        localRepository: LocalRepository = DocumentsLocalRepository()
    ) {
        self.localRepository = localRepository

        textureLayerUndoManager.addTextureLayersToUndoStackPublisher
            .sink { [weak self] in
                guard let `self` else { return }
                self.textureLayerUndoManager.addUndoObject(
                    undoObject: .init(
                        index: self.textureLayers.index,
                        layers: self.textureLayers.layers
                    ),
                    textureLayers: self.textureLayers
                )
                self.textureLayers.updateSelectedTextureAddress()
            }
            .store(in: &cancellables)

        textureLayerUndoManager.refreshCanvasPublisher
            .sink { [weak self] undoObject in
                self?.refreshCanvasWithUndoObjectSubject.send(undoObject)
            }
            .store(in: &cancellables)

        textureLayerUndoManager.canUndoPublisher
            .sink { [weak self] value in
                self?.refreshCanUndoSubject.send(value)
            }
            .store(in: &cancellables)

        textureLayerUndoManager.canRedoPublisher
            .sink { [weak self] value in
                self?.refreshCanRedoSubject.send(value)
            }
            .store(in: &cancellables)

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                guard let `self` else { return }
                switch tool {
                case .brush:
                    self.drawingTexture = self.brushDrawingTexture
                case .eraser:
                    self.drawingTexture = self.eraserDrawingTexture
                }
            }
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)
    }

    func initCanvas(
        textureSize: CGSize,
        canvasView: CanvasViewProtocol
    ) {
        guard let device else { return }

        brushDrawingTexture.initTexture(textureSize)
        eraserDrawingTexture.initTexture(textureSize)

        currentTexture.initTexture(textureSize: textureSize)
        textureLayers.initLayers(textureSize: textureSize)

        canvasTexture = MTKTextureUtils.makeTexture(device, textureSize)

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

    func apply(
        model: CanvasModel,
        to canvasView: CanvasViewProtocol
    ) {
        guard let device else { return }

        projectName = model.projectName

        textureLayerUndoManager.clear()

        brushDrawingTexture.initTexture(model.textureSize)
        eraserDrawingTexture.initTexture(model.textureSize)

        currentTexture.initTexture(textureSize: model.textureSize)
        textureLayers.initLayers(
            newLayers: model.layers,
            layerIndex: model.layerIndex,
            textureSize: model.textureSize
        )

        for i in 0 ..< textureLayers.layers.count {
            textureLayers.layers[i].updateThumbnail()
        }

        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        canvasTexture = MTKTextureUtils.makeTexture(device, model.textureSize)

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

    func apply(
        undoObject: TextureLayerUndoObject,
        to canvasView: CanvasViewProtocol
    ) {
        currentTexture.clearTexture()
        textureLayers.initLayers(
            index: undoObject.index,
            layers: undoObject.layers
        )

        for i in 0 ..< textureLayers.layers.count {
            textureLayers.layers[i].updateThumbnail()
        }

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    func onUpdateRenderTexture(canvasView: CanvasViewProtocol) {
        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

    func onViewDidAppear(
        _ drawableTextureSize: CGSize,
        canvasView: CanvasViewProtocol
    ) {
        // Initialize the canvas here if the renderTexture's texture is nil
        if canvasTexture == nil {
            initCanvas(
                textureSize: drawableTextureSize,
                canvasView: canvasView
            )
        }

        // Update the display of the Undo and Redo buttons
        textureLayerUndoManager.updateUndoComponents()
    }

    // Manage all finger positions on the screen using a Dictionary,
    // determine the gesture from it,
    // and based on that, either draw a line on the canvas or transform the canvas.
    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView,
        canvasView: CanvasViewProtocol
    ) {
        guard inputDevice.update(.finger) != .pencil else { return }

        fingerScreenTouchManager.append(
            event: event,
            in: view
        )

        switch screenTouchGesture.update(
            .init(from: fingerScreenTouchManager.touchArrayDictionary)
        ) {
        case .drawing:
            if !(grayscaleTextureCurveIterator is CanvasSmoothGrayscaleCurveIterator) {
                grayscaleTextureCurveIterator = CanvasSmoothGrayscaleCurveIterator()
            }
            if fingerScreenTouchManager.currentDictionaryKey == nil {
                fingerScreenTouchManager.currentDictionaryKey = fingerScreenTouchManager.touchArrayDictionary.keys.first
            }
            guard 
                let grayscaleTextureCurveIterator,
                let currentTouchKey = fingerScreenTouchManager.currentDictionaryKey
            else { return }

            let screenTouchPoints = fingerScreenTouchManager.getTouchPoints(for: currentTouchKey)
            let latestScreenTouchPoints = screenTouchPoints.elements(after: fingerScreenTouchManager.latestCanvasTouchPoint) ?? screenTouchPoints
            fingerScreenTouchManager.latestCanvasTouchPoint = latestScreenTouchPoints.last

            let touchPhase = latestScreenTouchPoints.currentTouchPhase

            let grayscaleTexturePoints: [CanvasGrayscaleDotPoint] = latestScreenTouchPoints.map {
                let textureSize = canvasTexture?.size ?? .zero
                let drawableSize = canvasView.renderTexture?.size ?? .zero

                let textureMatrix = adjustMatrixTranslation(
                    matrix: canvasTransformer.matrix.inverted(flipY: true),
                    frameSize: frameSize,
                    drawableSize: drawableSize,
                    textureSize: textureSize
                )
                let textureLocation: CGPoint = getLocationConvertedToTextureScale(
                    screenLocation: $0.location,
                    screenFrameSize: frameSize,
                    drawableSize: drawableSize,
                    textureSize: textureSize
                )
                return CanvasGrayscaleDotPoint.init(
                    touchPoint: .init(
                        location: textureLocation.apply(
                            with: textureMatrix,
                            textureSize: textureSize
                        ),
                        touch: $0
                    ),
                    diameter: CGFloat(drawingTool.diameter)
                )
            }

            grayscaleTextureCurveIterator.appendToIterator(
                points: grayscaleTexturePoints,
                touchPhase: touchPhase
            )

            // Retrieve curve points from the iterator and draw them onto `currentTexture`
            drawPointsOnCurrentTexture(
                grayscaleTexturePoints: grayscaleTextureCurveIterator.makeCurvePoints(
                    atEnd: touchPhase == .ended
                ),
                with: grayscaleTextureCurveIterator,
                touchPhase: touchPhase,
                with: canvasView.commandBuffer
            )

            mergeAllTextureLayersOnCanvasTexture(
                usingCurrentTextureWhileDrawing: true,
                with: canvasView.commandBuffer
            )

            drawTextureWithAspectFit(
                device: device,
                texture: canvasTexture,
                matrix: canvasTransformer.matrix,
                withBackgroundColor: (230, 230, 230),
                frameSize: frameSize,
                on: canvasView.renderTexture,
                commandBuffer: canvasView.commandBuffer
            )

            if requestShowingLayerViewSubject.value && touchPhase == .ended {
                // Makes a thumbnail with a slight delay to allow processing after the Metal command buffer has completed
                updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
            }

            pauseDisplayLinkLoop(
                [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(touchPhase),
                canvasView: canvasView
            )

        case .transforming:
            if canvasTransformer.isCurrentKeysNil {
                canvasTransformer.initTransforming(fingerScreenTouchManager.touchArrayDictionary)
            }

            canvasTransformer.transformCanvas(
                screenCenter: .init(
                    x: frameSize.width * 0.5,
                    y: frameSize.height * 0.5
                ),
                fingerScreenTouchManager.touchArrayDictionary
            )
            if fingerScreenTouchManager.touchArrayDictionary.containsPhases([.ended]) {
                canvasTransformer.finishTransforming()
            }

            drawTextureWithAspectFit(
                device: device,
                texture: canvasTexture,
                matrix: canvasTransformer.matrix,
                withBackgroundColor: (230, 230, 230),
                frameSize: frameSize,
                on: canvasView.renderTexture,
                commandBuffer: canvasView.commandBuffer
            )

            pauseDisplayLinkLoop(
                fingerScreenTouchManager.touchArrayDictionary.containsPhases(
                    [.ended, .cancelled]
                ),
                canvasView: canvasView
            )

        default:
            break
        }

        fingerScreenTouchManager.removeIfLastElementMatches(phases: [.ended, .cancelled])

        if fingerScreenTouchManager.isEmpty && isAllFingersReleasedFromScreen(touches: touches, with: event) {
            initDrawingParameters()
        }
    }

    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView,
        canvasView: CanvasViewProtocol
    ) {
        // Cancel if there is finger input
        if inputDevice.status == .finger {
            cancelFingerInput(canvasView)
        }
        // Set `inputDevice` to '.pencil'
        let _ = inputDevice.update(.pencil)

        // Make `grayscaleTextureCurveIterator` and reset the parameters when a touch begins
        if estimatedTouches.contains(where: {$0.phase == .began}) {
            grayscaleTextureCurveIterator = CanvasDefaultGrayscaleCurveIterator()
            pencilScreenTouchPoints.reset()
        }

        // Append estimated values to the array
        event?.allTouches?
            .compactMap { $0.type == .pencil ? $0 : nil }
            .sorted { $0.timestamp < $1.timestamp }
            .forEach { touch in
                event?.coalescedTouches(for: touch)?.forEach { coalescedTouch in
                    pencilScreenTouchPoints.appendEstimatedValue(
                        .init(touch: coalescedTouch, view: view)
                    )
                }
            }
    }

    func onPencilGestureDetected(
        actualTouches: Set<UITouch>,
        view: UIView,
        canvasView: CanvasViewProtocol
    ) {
        // Combine `actualTouches` with the estimated values to create actual values, and append them to an array
        let actualTouchArray = Array(actualTouches).sorted { $0.timestamp < $1.timestamp }
        actualTouchArray.forEach { actualTouch in
            pencilScreenTouchPoints.appendActualValueWithEstimatedValue(actualTouch)
        }
        if pencilScreenTouchPoints.hasActualValueReplacementCompleted {
            pencilScreenTouchPoints.appendLastEstimatedTouchPointToActualTouchPointArray()
        }
        guard let grayscaleTextureCurveIterator else { return }

        guard
            // Wait to ensure sufficient time has passed since the previous process
            // as the operation may not work correctly if the time difference is too short.
            pencilScreenTouchPoints.hasSufficientTimeElapsedSincePreviousProcess(allowedDifferenceInSeconds: 0.03) ||
            [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(
                pencilScreenTouchPoints.actualTouchPointArray.currentTouchPhase
            )
        else { return }

        // Retrieve the latest touch points necessary for drawing from the array of stored touch points
        let latestScreenTouchArray = pencilScreenTouchPoints.latestActualTouchPoints
        pencilScreenTouchPoints.updateLatestActualTouchPoint()

        let touchPhase = latestScreenTouchArray.currentTouchPhase

        // Convert screen scale points to texture scale, and apply the canvas transformation values to the points
        let latestTextureTouchArray: [CanvasGrayscaleDotPoint] = latestScreenTouchArray.map {
            let textureSize = canvasTexture?.size ?? .zero
            let drawableSize = canvasView.renderTexture?.size ?? .zero

            let textureMatrix = adjustMatrixTranslation(
                matrix: canvasTransformer.matrix.inverted(flipY: true),
                frameSize: frameSize,
                drawableSize: drawableSize,
                textureSize: textureSize
            )
            let textureLocation: CGPoint = getLocationConvertedToTextureScale(
                screenLocation: $0.location,
                screenFrameSize: frameSize,
                drawableSize: drawableSize,
                textureSize: textureSize
            )
            return CanvasGrayscaleDotPoint.init(
                touchPoint: .init(
                    location: textureLocation.apply(
                        with: textureMatrix,
                        textureSize: textureSize
                    ),
                    touch: $0
                ),
                diameter: CGFloat(drawingTool.diameter)
            )
        }

        grayscaleTextureCurveIterator.appendToIterator(
            points: latestTextureTouchArray,
            touchPhase: touchPhase
        )

        // Retrieve curve points from the iterator and draw them onto `currentTexture`
        drawPointsOnCurrentTexture(
            grayscaleTexturePoints: grayscaleTextureCurveIterator.makeCurvePoints(
                atEnd: touchPhase == .ended
            ),
            with: grayscaleTextureCurveIterator,
            touchPhase: touchPhase,
            with: canvasView.commandBuffer
        )

        mergeAllTextureLayersOnCanvasTexture(
            usingCurrentTextureWhileDrawing: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        if requestShowingLayerViewSubject.value && touchPhase == .ended {
            // Makes a thumbnail with a slight delay to allow processing after the Metal command buffer has completed
            updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
        }

        pauseDisplayLinkLoop(
            [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(touchPhase),
            canvasView: canvasView
        )

        if [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(touchPhase) {
            initDrawingParameters()
        }
    }

}

extension CanvasViewModel {

    private func initDrawingParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        canvasTransformer.reset()

        fingerScreenTouchManager.reset()
        pencilScreenTouchPoints.reset()
        grayscaleTextureCurveIterator = nil
    }

    private func cancelFingerInput(_ canvasView: CanvasViewProtocol) {
        fingerScreenTouchManager.reset()
        canvasTransformer.reset()
        drawingTexture?.clearDrawingTexture()

        grayscaleTextureCurveIterator = nil

        canvasView.clearCommandBuffer()

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    private func drawPointsOnCurrentTexture(
        grayscaleTexturePoints: [CanvasGrayscaleDotPoint],
        with grayscaleCurve: CanvasGrayscaleCurveIterator?,
        touchPhase: UITouch.Phase,
        with commandBuffer: MTLCommandBuffer
    ) {
        if let drawingTexture = drawingTexture as? CanvasEraserDrawingTexture,
           let selectedTexture = textureLayers.selectedLayer?.texture {
            drawingTexture.drawPointsOnEraserDrawingTexture(
                points: grayscaleTexturePoints,
                alpha: drawingTool.eraserAlpha,
                srcTexture: selectedTexture,
                commandBuffer
            )
        } else if let drawingTexture = drawingTexture as? CanvasBrushDrawingTexture {
            drawingTexture.drawPointsOnBrushDrawingTexture(
                points: grayscaleTexturePoints,
                color: drawingTool.brushColor,
                alpha: drawingTool.brushColor.alpha,
                commandBuffer
            )
        }

        // Combine `selectedLayer.texture` and `drawingTexture`, then render them onto currentTexture
        drawingTexture?.drawDrawingTexture(
            includingSelectedTexture: textureLayers.selectedLayer?.texture,
            on: currentTexture.currentTexture,
            with: commandBuffer
        )

        if touchPhase == .ended {
            // Add `textureLayer` to the undo stack 
            // when the drawing is ended and before `DrawingTexture` is merged with `selectedLayer.texture`
            textureLayerUndoManager.addCurrentLayersToUndoStack()

            // Draw `drawingTexture` onto `selectedLayer.texture`
            drawingTexture?.mergeDrawingTexture(
                into: textureLayers.selectedLayer?.texture,
                commandBuffer
            )
        }
    }

    private func mergeAllTextureLayersOnCanvasTexture(
        alsoUpdateUnselectedLayers: Bool = false,
        usingCurrentTextureWhileDrawing usingCurrentTexture: Bool = false,
        with commandBuffer: MTLCommandBuffer
    ) {
        if alsoUpdateUnselectedLayers {
            textureLayers.updateUnselectedLayers(
                to: commandBuffer
            )
        }

        textureLayers.mergeAllTextures(
            usingCurrentTexture: usingCurrentTexture ? currentTexture : nil,
            backgroundColor: drawingTool.backgroundColor,
            on: canvasTexture,
            with: commandBuffer
        )
    }

}

extension CanvasViewModel {

    /// Start or stop the display link loop.
    private func pauseDisplayLinkLoop(_ pause: Bool, canvasView: CanvasViewProtocol) {
        if pause {
            if pauseDisplayLinkSubject.value == false {
                // Pause the display link after updating the display.
                canvasView.setNeedsDisplay()
                pauseDisplayLinkSubject.send(true)
            }

        } else {
            if pauseDisplayLinkSubject.value == true {
                pauseDisplayLinkSubject.send(false)
            }
        }
    }

    private func isAllFingersReleasedFromScreen(
        touches: Set<UITouch>,
        with event: UIEvent?
    ) -> Bool {
        touches.count == event?.allTouches?.count &&
        touches.contains { $0.phase == .ended || $0.phase == .cancelled }
    }

    private func updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: UInt64) {
        Task {
            try await Task.sleep(nanoseconds: nanosecondsDuration)

            DispatchQueue.main.async { [weak self] in
                guard let `self` else { return }
                self.textureLayers.updateThumbnail(index: self.textureLayers.index)
            }
        }
    }

    /// Draw `texture` onto `destinationTexture` with aspect fit
    private func drawTextureWithAspectFit(
        device: MTLDevice?,
        texture: MTLTexture?,
        matrix: CGAffineTransform?,
        withBackgroundColor color: (Int, Int, Int)? = nil,
        frameSize: CGSize,
        on destinationTexture: MTLTexture?,
        commandBuffer: MTLCommandBuffer
    ) {
        guard
            let device,
            let texture,
            let destinationTexture
        else { return }

        // Calculate the scale to fit the source size within the destination size
        let textureToDrawableFitScale = ViewSize.getScaleToFit(texture.size, to: destinationTexture.size)

        guard
            let textureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                device: device,
                matrix: matrix,
                frameSize: frameSize,
                sourceSize: .init(
                    width: texture.size.width * textureToDrawableFitScale,
                    height: texture.size.height * textureToDrawableFitScale
                ),
                destinationSize: destinationTexture.size,
                nodes: textureNodes
            )
        else { return }

        MTLRenderer.drawTexture(
            texture: texture,
            buffers: textureBuffers,
            withBackgroundColor: color,
            on: destinationTexture,
            with: commandBuffer
        )
    }

    private func getLocationConvertedToTextureScale(
        screenLocation: CGPoint,
        screenFrameSize: CGSize,
        drawableSize: CGSize,
        textureSize: CGSize
    ) -> CGPoint {
        if textureSize != drawableSize {
            let drawableToTextureFillScale = ViewSize.getScaleToFill(drawableSize, to: textureSize)
            let drawableLocation: CGPoint = .init(
                x: screenLocation.x * (drawableSize.width / screenFrameSize.width),
                y: screenLocation.y * (drawableSize.width / screenFrameSize.width)
            )
            return .init(
                x: drawableLocation.x * drawableToTextureFillScale + (textureSize.width - drawableSize.width * drawableToTextureFillScale) * 0.5,
                y: drawableLocation.y * drawableToTextureFillScale + (textureSize.height - drawableSize.height * drawableToTextureFillScale) * 0.5
            )
        } else {
            return .init(
                x: screenLocation.x * (textureSize.width / screenFrameSize.width),
                y: screenLocation.y * (textureSize.width / screenFrameSize.width)
            )
        }
    }

    func adjustMatrixTranslation(
        matrix: CGAffineTransform,
        frameSize: CGSize,
        drawableSize: CGSize,
        textureSize: CGSize
    ) -> CGAffineTransform {

        let drawableScale = ViewSize.getScaleToFit(textureSize, to: drawableSize)
        let drawableTextureSize: CGSize = .init(
            width: textureSize.width * drawableScale,
            height: textureSize.height * drawableScale
        )

        let frameToTextureFitScale = ViewSize.getScaleToFit(frameSize, to: textureSize)
        let drawableTextureToDrawableFillScale = ViewSize.getScaleToFill(drawableTextureSize, to: drawableSize)

        var matrix = matrix
        matrix.tx *= (frameToTextureFitScale * drawableTextureToDrawableFillScale)
        matrix.ty *= (frameToTextureFitScale * drawableTextureToDrawableFillScale)
        return matrix
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {
        textureLayerUndoManager.undo()
    }
    func didTapRedoButton() {
        textureLayerUndoManager.redo()
    }

    func didTapLayerButton() {
        textureLayers.updateThumbnail(index: textureLayers.index)
        requestShowingLayerViewSubject.send(!requestShowingLayerViewSubject.value)
    }

    func didTapResetTransformButton(canvasView: CanvasViewProtocol) {
        canvasTransformer.setMatrix(.identity)

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

    func didTapNewCanvasButton(canvasView: CanvasViewProtocol) {
        guard
            let renderTexture = canvasView.renderTexture
        else { return }

        projectName = Calendar.currentDate

        canvasTransformer.setMatrix(.identity)

        brushDrawingTexture.initTexture(renderTexture.size)
        eraserDrawingTexture.initTexture(renderTexture.size)

        currentTexture.initTexture(textureSize: renderTexture.size)
        textureLayers.initLayers(textureSize: renderTexture.size)

        textureLayerUndoManager.clear()

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton(canvasView: CanvasViewProtocol) {
        saveFile(renderTexture: canvasView.renderTexture!)
    }

    // MARK: Layers
    func didTapLayer(
        layer: TextureLayer,
        canvasView: CanvasViewProtocol
    ) {
        guard let index = textureLayers.getIndex(layer: layer) else { return }
        textureLayers.index = index

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }
    func didTapAddLayerButton(
        canvasView: CanvasViewProtocol
    ) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let renderTexture = canvasView.renderTexture
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        let layer: TextureLayer = .init(
            texture: MTKTextureUtils.makeBlankTexture(
                device,
                renderTexture.size
            ),
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
        textureLayers.addLayer(layer)

        // Makes a thumbnail
        if let index = textureLayers.getIndex(layer: layer) {
            textureLayers.updateThumbnail(index: index)
        }

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }
    func didTapRemoveLayerButton(
        canvasView: CanvasViewProtocol
    ) {
        guard
            textureLayers.layers.count > 1,
            let layer = textureLayers.selectedLayer
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        textureLayers.removeLayer(layer)

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }
    func didTapLayerVisibility(
        layer: TextureLayer,
        isVisible: Bool,
        canvasView: CanvasViewProtocol
    ) {
        guard 
            let index = textureLayers.getIndex(layer: layer)
        else { return }

        textureLayers.updateLayer(
            index: index,
            isVisible: isVisible
        )

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }
    func didChangeLayerAlpha(
        layer: TextureLayer,
        value: Int,
        canvasView: CanvasViewProtocol
    ) {
        guard
            let index = textureLayers.getIndex(layer: layer)
        else { return }

        textureLayers.updateLayer(
            index: index,
            alpha: value
        )

        mergeAllTextureLayersOnCanvasTexture(
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }
    func didEditLayerTitle(
        layer: TextureLayer,
        title: String
    ) {
        guard
            let index = textureLayers.getIndex(layer: layer)
        else { return }

        textureLayers.updateLayer(
            index: index,
            title: title
        )
    }
    func didMoveLayers(
        layer: TextureLayer,
        source: IndexSet,
        destination: Int,
        canvasView: CanvasViewProtocol
    ) {
        textureLayerUndoManager.addCurrentLayersToUndoStack()

        textureLayers.moveLayer(
            fromOffsets: source,
            toOffset: destination
        )

        mergeAllTextureLayersOnCanvasTexture(
            alsoUpdateUnselectedLayers: true,
            with: canvasView.commandBuffer
        )

        drawTextureWithAspectFit(
            device: device,
            texture: canvasTexture,
            matrix: canvasTransformer.matrix,
            withBackgroundColor: (230, 230, 230),
            frameSize: frameSize,
            on: canvasView.renderTexture,
            commandBuffer: canvasView.commandBuffer
        )

        canvasView.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    private func loadFile(from filePath: String) {
        localRepository?.loadDataFromDocuments(
            sourceURL: URL.documents.appendingPathComponent(filePath)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription) }
        }, receiveValue: { [weak self] response in
            self?.refreshCanvasSubject.send(response)
        })
        .store(in: &cancellables)
    }

    private func saveFile(renderTexture: MTLTexture) {
        localRepository?.saveDataToDocuments(
            renderTexture: renderTexture,
            textureLayers: textureLayers,
            drawingTool: drawingTool,
            to: URL.documents.appendingPathComponent(
                CanvasModel.getZipFileName(projectName: projectName)
            )
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription) }
        }, receiveValue: {})
        .store(in: &cancellables)
    }

}
