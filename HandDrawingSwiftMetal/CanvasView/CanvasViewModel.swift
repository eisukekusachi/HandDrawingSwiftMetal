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

    private var canvasView: CanvasViewProtocol?

    /// A texture with a background color, composed of `drawingTexture` and `currentTexture`
    private var canvasTexture: MTLTexture?

    /// A protocol for managing current drawing texture
    private (set) var drawingTexture: CanvasDrawingTextureProtocol?

    /// A texture that combines the texture of the currently selected `TextureLayer` and `drawingTexture`
    private var currentTexture: MTLTexture?

    /// A drawing texture with a brush
    private let brushDrawingTexture = CanvasBrushDrawingTexture()
    /// A drawing texture with an eraser
    private let eraserDrawingTexture = CanvasEraserDrawingTexture()

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let requestShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestCanvasTextureDrawToRenderTextureSubject = PassthroughSubject<Void, Never>()

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

        requestCanvasTextureDrawToRenderTextureSubject
            .sink { [weak self] _ in
                guard
                    let `self`,
                    let sourceTexture = self.canvasTexture,
                    let destinationTexture = self.canvasView?.renderTexture,
                    let commandBuffer = self.canvasView?.commandBuffer
                else { return }

                // Calculate the scale to fit the source size within the destination size
                let textureToDrawableFitScale = ViewSize.getScaleToFit(sourceTexture.size, to: destinationTexture.size)

                guard
                    let textureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                        device: self.device,
                        matrix: self.canvasTransformer.matrix,
                        frameSize: self.frameSize,
                        sourceSize: .init(
                            width: sourceTexture.size.width * textureToDrawableFitScale,
                            height: sourceTexture.size.height * textureToDrawableFitScale
                        ),
                        destinationSize: destinationTexture.size,
                        nodes: textureNodes
                    )
                else { return }

                MTLRenderer.drawTexture(
                    texture: sourceTexture,
                    buffers: textureBuffers,
                    withBackgroundColor: Constants.blankAreaBackgroundColor,
                    on: destinationTexture,
                    with: commandBuffer
                )
            }
            .store(in: &cancellables)

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

    func setCanvasView(_ canvasView: CanvasViewProtocol) {
        self.canvasView = canvasView
    }

    func initCanvas(
        textureSize: CGSize
    ) {
        guard let device else { return }

        brushDrawingTexture.initTexture(textureSize)
        eraserDrawingTexture.initTexture(textureSize)

        textureLayers.initLayers(textureSize: textureSize)

        currentTexture = MTKTextureUtils.makeTexture(device, textureSize)

        canvasTexture = MTKTextureUtils.makeTexture(device, textureSize)
    }

    func apply(model: CanvasModel) {
        guard 
            let device,
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        projectName = model.projectName

        textureLayerUndoManager.clear()

        brushDrawingTexture.initTexture(model.textureSize)
        eraserDrawingTexture.initTexture(model.textureSize)

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

        currentTexture = MTKTextureUtils.makeTexture(device, model.textureSize)

        canvasTexture = MTKTextureUtils.makeTexture(device, model.textureSize)

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }

    func apply(undoObject: TextureLayerUndoObject) {
        guard
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        textureLayers.initLayers(
            index: undoObject.index,
            layers: undoObject.layers
        )

        for i in 0 ..< textureLayers.layers.count {
            textureLayers.layers[i].updateThumbnail()
        }

        MTLRenderer.clear(texture: currentTexture, commandBuffer)

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    func onUpdateRenderTexture() {
        guard
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        // Initialize the canvas here if `canvasTexture` is nil
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(
                textureSize: textureSize
            )
        }

        // Redraws the canvas when the screen rotates and the canvas size changes.
        // Therefore, this code is placed outside the block.
        mergeLayersOnCanvasTextureWithBackgroundColor(
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }

    func onViewDidAppear(
        _ drawableTextureSize: CGSize
    ) {
        guard
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        // Since `func onUpdateRenderTexture` is not called at app launch on iPhone,
        // initialize the canvas here.
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(
                textureSize: textureSize
            )
        }

        mergeLayersOnCanvasTextureWithBackgroundColor(
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()

        // Update the display of the Undo and Redo buttons
        textureLayerUndoManager.updateUndoComponents()
    }

    // Manage all finger positions on the screen using a Dictionary,
    // determine the gesture from it,
    // and based on that, either draw a line on the canvas or transform the canvas.
    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        guard 
            inputDevice.update(.finger) != .pencil,
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

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

                let textureMatrix = getMatrixAdjustedTranslations(
                    matrix: canvasTransformer.matrix.inverted(flipY: true),
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
                with: commandBuffer
            )

            mergeLayersOnCanvasTextureWithBackgroundColor(
                currentTexture: currentTexture,
                with: commandBuffer
            )

            if requestShowingLayerViewSubject.value && touchPhase == .ended {
                updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
            }

            requestCanvasTextureDrawToRenderTextureSubject.send()

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

            requestCanvasTextureDrawToRenderTextureSubject.send()

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
        view: UIView
    ) {
        // Cancel if there is finger input
        if inputDevice.status == .finger {
            cancelFingerInput()
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
        view: UIView
    ) {
        guard
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

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

            let textureMatrix = getMatrixAdjustedTranslations(
                matrix: canvasTransformer.matrix.inverted(flipY: true),
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
            with: commandBuffer
        )

        mergeLayersOnCanvasTextureWithBackgroundColor(
            currentTexture: currentTexture,
            with: commandBuffer
        )

        if requestShowingLayerViewSubject.value && touchPhase == .ended {
            updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
        }

        requestCanvasTextureDrawToRenderTextureSubject.send()

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

    private func cancelFingerInput() {
        guard
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        fingerScreenTouchManager.reset()
        canvasTransformer.reset()
        drawingTexture?.clearDrawingTexture()

        grayscaleTextureCurveIterator = nil

        canvasView.clearCommandBuffer()

        requestCanvasTextureDrawToRenderTextureSubject.send()
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
            on: currentTexture,
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

    private func mergeLayersOnCanvasTextureWithBackgroundColor(
        alsoUpdateUnselectedLayers: Bool = false,
        currentTexture: MTLTexture? = nil,
        with commandBuffer: MTLCommandBuffer
    ) {
        if alsoUpdateUnselectedLayers {
            textureLayers.updateUnselectedLayers(
                to: commandBuffer
            )
        }

        textureLayers.mergeAllTextures(
            usingCurrentTexture: currentTexture,
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

    /// Makes a thumbnail with a slight delay to allow processing after the Metal command buffer has completed
    private func updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: UInt64) {
        Task {
            try await Task.sleep(nanoseconds: nanosecondsDuration)

            DispatchQueue.main.async { [weak self] in
                guard let `self` else { return }
                self.textureLayers.updateThumbnail(index: self.textureLayers.index)
            }
        }
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

    private func getMatrixAdjustedTranslations(
        matrix: CGAffineTransform,
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

    func didTapResetTransformButton() {
        guard
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        canvasTransformer.setMatrix(.identity)

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }

    func didTapNewCanvasButton() {
        guard
            let device,
            let canvasView,
            let renderTextureSize = canvasView.renderTexture?.size,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        projectName = Calendar.currentDate

        canvasTransformer.setMatrix(.identity)

        brushDrawingTexture.initTexture(renderTextureSize)
        eraserDrawingTexture.initTexture(renderTextureSize)

        textureLayers.initLayers(textureSize: renderTextureSize)

        textureLayerUndoManager.clear()

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        currentTexture = MTKTextureUtils.makeTexture(device, renderTextureSize)

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        guard let renderTexture = canvasView?.renderTexture else { return }
        saveFile(renderTexture: renderTexture)
    }

    // MARK: Layers
    func didTapLayer(layer: TextureLayer) {
        guard
            let index = textureLayers.getIndex(layer: layer),
            let canvasView,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        textureLayers.index = index

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }
    func didTapAddLayerButton() {
        guard
            let device,
            let canvasView,
            let renderTextureSize = canvasView.renderTexture?.size,
            let commandBuffer = canvasView.commandBuffer
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        let layer: TextureLayer = .init(
            texture: MTKTextureUtils.makeBlankTexture(
                device,
                renderTextureSize
            ),
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
        textureLayers.addLayer(layer)

        // Makes a thumbnail
        if let index = textureLayers.getIndex(layer: layer) {
            textureLayers.updateThumbnail(index: index)
        }

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView.setNeedsDisplay()
    }
    func didTapRemoveLayerButton() {
        guard
            textureLayers.layers.count > 1,
            let layer = textureLayers.selectedLayer,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        textureLayers.removeLayer(layer)

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView?.setNeedsDisplay()
    }
    func didTapLayerVisibility(
        layer: TextureLayer,
        isVisible: Bool
    ) {
        guard 
            let index = textureLayers.getIndex(layer: layer),
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        textureLayers.updateLayer(
            index: index,
            isVisible: isVisible
        )

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView?.setNeedsDisplay()
    }
    func didChangeLayerAlpha(
        layer: TextureLayer,
        value: Int
    ) {
        guard
            let index = textureLayers.getIndex(layer: layer),
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        textureLayers.updateLayer(
            index: index,
            alpha: value
        )

        mergeLayersOnCanvasTextureWithBackgroundColor(
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView?.setNeedsDisplay()
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
        destination: Int
    ) {
        guard
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        textureLayers.moveLayer(
            fromOffsets: source,
            toOffset: destination
        )

        mergeLayersOnCanvasTextureWithBackgroundColor(
            alsoUpdateUnselectedLayers: true,
            with: commandBuffer
        )

        requestCanvasTextureDrawToRenderTextureSubject.send()
        canvasView?.setNeedsDisplay()
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
