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

    private var drawingCurve: CanvasDrawingCurve?

    private var drawingDisplayLink: CADisplayLink?

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

        setupDisplayLink()

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

    private func setupDisplayLink() {
        // Configure the display link for rendering.
        drawingDisplayLink = CADisplayLink(target: self, selector: #selector(updateCanvasViewWhileDrawing))
        drawingDisplayLink?.add(to: .current, forMode: .common)
        drawingDisplayLink?.isPaused = true
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
            let canvasView
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

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
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

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
    }

}

extension CanvasViewModel {

    func onUpdateRenderTexture() {
        guard let canvasView else { return }

        // Initialize the canvas here if `canvasTexture` is nil
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(
                textureSize: textureSize
            )
        }

        // Redraws the canvas when the device rotates and the canvas size changes.
        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            on: canvasView
        )
    }

    func onViewDidAppear(
        _ drawableTextureSize: CGSize
    ) {
        assert(self.canvasView != nil, "var canvasView is nil.")

        guard let canvasView else { return }

        // Since `func onUpdateRenderTexture` is not called at app launch on iPhone,
        // initialize the canvas here.
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(
                textureSize: textureSize
            )
        }

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            on: canvasView
        )

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
        guard inputDevice.update(.finger) != .pencil else { return }

        fingerScreenTouchManager.append(
            event: event,
            in: view
        )

        switch screenTouchGesture.update(
            .init(from: fingerScreenTouchManager.touchArrayDictionary)
        ) {
        case .drawing:
            if !(drawingCurve is CanvasDrawingCurveWithFinger) {
                drawingCurve = CanvasDrawingCurveWithFinger()
            }
            if fingerScreenTouchManager.currentDictionaryKey == nil {
                fingerScreenTouchManager.currentDictionaryKey = fingerScreenTouchManager.touchArrayDictionary.keys.first
            }
            guard 
                let drawingCurve,
                let currentTouchKey = fingerScreenTouchManager.currentDictionaryKey,
                let screenTouchPoints = fingerScreenTouchManager.getLatestTouchPoints(for: currentTouchKey)
            else { return }

            let touchPhase = screenTouchPoints.currentTouchPhase

            let grayscaleTextureDotPoints: [CanvasGrayscaleDotPoint] = screenTouchPoints.compactMap {
                guard
                    let textureSize = canvasTexture?.size,
                    let drawableSize = canvasView?.renderTexture?.size
                else { return nil }

                return convertScreenTouchPointToTextureDotPoint(
                    touchPoint: $0,
                    textureSize: textureSize,
                    drawableSize: drawableSize
                )
            }

            drawingCurve.appendToIterator(
                points: grayscaleTextureDotPoints,
                touchPhase: touchPhase
            )

            pauseDisplayLinkLoop(drawingCurve.isDrawingFinished)

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

            displayCanvasTexture(canvasTexture: canvasTexture, on: canvasView)

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
        inputDevice.update(.pencil)

        // Make `grayscaleTextureCurveIterator` and reset the parameters when a touch begins
        if estimatedTouches.contains(where: {$0.phase == .began}) {
            drawingCurve = CanvasDrawingCurveWithPencil()
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
        guard let drawingCurve else { return }

        // Combine `actualTouches` with the estimated values to create actual values, and append them to an array
        let actualTouchArray = Array(actualTouches).sorted { $0.timestamp < $1.timestamp }
        actualTouchArray.forEach { actualTouch in
            pencilScreenTouchPoints.appendActualValueWithEstimatedValue(actualTouch)
        }
        if pencilScreenTouchPoints.hasActualValueReplacementCompleted {
            pencilScreenTouchPoints.appendLastEstimatedTouchPointToActualTouchPointArray()
        }

        let screenTouchPoints = pencilScreenTouchPoints.getLatestTouchPoints()

        let touchPhase = screenTouchPoints.currentTouchPhase

        // Convert screen scale points to texture scale, and apply the canvas transformation values to the points
        let latestTextureTouchArray: [CanvasGrayscaleDotPoint] = screenTouchPoints.compactMap {
            guard
                let textureSize = canvasTexture?.size,
                let drawableSize = canvasView?.renderTexture?.size
            else { return nil }

            return convertScreenTouchPointToTextureDotPoint(
                touchPoint: $0,
                textureSize: textureSize,
                drawableSize: drawableSize
            )
        }

        drawingCurve.appendToIterator(
            points: latestTextureTouchArray,
            touchPhase: touchPhase
        )

        pauseDisplayLinkLoop(drawingCurve.isDrawingFinished)
    }

}

extension CanvasViewModel {

    @objc private func updateCanvasViewWhileDrawing() {
        guard
            let drawingCurve,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        if let texturePoints = drawingCurve.makeCurvePointsFromIterator() {
            if let drawingTexture = drawingTexture as? CanvasEraserDrawingTexture,
               let selectedLayerTexture = textureLayers.selectedLayer?.texture {
                drawingTexture.drawPointsOnEraserDrawingTexture(
                    points: texturePoints,
                    alpha: drawingTool.eraserAlpha,
                    srcTexture: selectedLayerTexture,
                    commandBuffer
                )
            } else if let drawingTexture = drawingTexture as? CanvasBrushDrawingTexture {
                drawingTexture.drawPointsOnBrushDrawingTexture(
                    points: texturePoints,
                    color: drawingTool.brushColor,
                    alpha: drawingTool.brushColor.alpha,
                    commandBuffer
                )
            }
        }

        // Combine `selectedLayer.texture` and `drawingTexture`, then render them onto currentTexture
        drawingTexture?.drawDrawingTexture(
            includingSelectedTexture: textureLayers.selectedLayer?.texture,
            on: currentTexture,
            with: commandBuffer
        )

        if drawingCurve.isDrawingFinished {
            // Add `textureLayer` to the undo stack
            // when the drawing is ended and before `DrawingTexture` is merged with `selectedLayer.texture`
            textureLayerUndoManager.addCurrentLayersToUndoStack()

            // Draw `drawingTexture` onto `selectedLayer.texture`
            drawingTexture?.mergeDrawingTexture(
                into: textureLayers.selectedLayer?.texture,
                commandBuffer
            )
        }

        textureLayers.mergeAllTextures(
            usingCurrentTexture: currentTexture,
            backgroundColor: drawingTool.backgroundColor,
            on: canvasTexture,
            with: commandBuffer
        )

        displayCanvasTexture(canvasTexture: canvasTexture, on: canvasView)

        if requestShowingLayerViewSubject.value && drawingCurve.isDrawingComplete {
            updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
        }

        if drawingCurve.isDrawingFinished {
            initDrawingParameters()
        }
    }

    private func initDrawingParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        canvasTransformer.reset()

        fingerScreenTouchManager.reset()
        pencilScreenTouchPoints.reset()

        drawingCurve = nil
    }

    private func cancelFingerInput() {
        fingerScreenTouchManager.reset()
        canvasTransformer.reset()
        drawingTexture?.clearDrawingTexture()

        drawingCurve = nil

        canvasView?.clearCommandBuffer()

        displayCanvasTexture(canvasTexture: canvasTexture, on: canvasView)
    }

}

extension CanvasViewModel {

    private func displayCanvasTextureWithMergedLayers(
        textureLayers: TextureLayers,
        canvasTexture: MTLTexture?,
        canvasTextureBackgroundColor: UIColor,
        isUnselectedLayerMergeNeeded: Bool = false,
        on canvasView: CanvasViewProtocol?
    ) {
        guard let commandBuffer = canvasView?.commandBuffer else { return }

        if isUnselectedLayerMergeNeeded {
            textureLayers.updateUnselectedLayers(
                to: commandBuffer
            )
        }

        textureLayers.mergeAllTextures(
            backgroundColor: canvasTextureBackgroundColor,
            on: canvasTexture,
            with: commandBuffer
        )

        displayCanvasTexture(canvasTexture: canvasTexture, on: canvasView)
    }

    private func displayCanvasTexture(
        canvasTexture: MTLTexture?,
        on canvasView: CanvasViewProtocol?
    ) {
        guard
            let device,
            let sourceTexture = canvasTexture,
            let destinationTexture = canvasView?.renderTexture,
            let sourceTextureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                device: device,
                matrix: canvasTransformer.matrix,
                frameSize: frameSize,
                sourceSize: .init(
                    width: sourceTexture.size.width * ViewSize.getScaleToFit(sourceTexture.size, to: destinationTexture.size),
                    height: sourceTexture.size.height * ViewSize.getScaleToFit(sourceTexture.size, to: destinationTexture.size)
                ),
                destinationSize: destinationTexture.size,
                nodes: textureNodes
            ),
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        MTLRenderer.drawTexture(
            texture: sourceTexture,
            buffers: sourceTextureBuffers,
            withBackgroundColor: Constants.blankAreaBackgroundColor,
            on: destinationTexture,
            with: commandBuffer
        )

        canvasView?.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    /// Start or stop the display link loop.
    private func pauseDisplayLinkLoop(_ pause: Bool) {
        if pause {
            if drawingDisplayLink?.isPaused == false {
                // Pause the display link after updating the display.
                updateCanvasViewWhileDrawing()
                drawingDisplayLink?.isPaused = true
            }

        } else {
            if drawingDisplayLink?.isPaused == true {
                drawingDisplayLink?.isPaused = false
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

    private func convertScreenTouchPointToTextureDotPoint(
        touchPoint: CanvasTouchPoint,
        textureSize: CGSize,
        drawableSize: CGSize
    ) -> CanvasGrayscaleDotPoint {

        let textureMatrix = getMatrixAdjustedTranslations(
            matrix: canvasTransformer.matrix.inverted(flipY: true),
            drawableSize: drawableSize,
            textureSize: textureSize
        )
        let textureLocation = getLocationConvertedToTextureScale(
            screenLocation: touchPoint.location,
            screenFrameSize: frameSize,
            drawableSize: drawableSize,
            textureSize: textureSize
        )
        return .init(
            touchPoint: .init(
                location: textureLocation.apply(
                    with: textureMatrix,
                    textureSize: textureSize
                ),
                touch: touchPoint
            ),
            diameter: CGFloat(drawingTool.diameter)
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
        canvasTransformer.setMatrix(.identity)

        displayCanvasTexture(canvasTexture: canvasTexture, on: canvasView)
    }

    func didTapNewCanvasButton() {
        guard
            let device,
            let canvasView,
            let renderTextureSize = canvasView.renderTexture?.size
        else { return }

        projectName = Calendar.currentDate

        canvasTransformer.setMatrix(.identity)

        brushDrawingTexture.initTexture(renderTextureSize)
        eraserDrawingTexture.initTexture(renderTextureSize)

        textureLayers.initLayers(textureSize: renderTextureSize)

        textureLayerUndoManager.clear()

        currentTexture = MTKTextureUtils.makeTexture(device, renderTextureSize)

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
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
        guard let index = textureLayers.getIndex(layer: layer)  else { return }

        textureLayers.index = index

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
    }
    func didTapAddLayerButton() {
        guard
            let device,
            let renderTextureSize = canvasView?.renderTexture?.size
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

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
    }
    func didTapRemoveLayerButton() {
        guard
            textureLayers.layers.count > 1,
            let layer = textureLayers.selectedLayer
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        textureLayers.removeLayer(layer)

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
    }
    func didTapLayerVisibility(
        layer: TextureLayer,
        isVisible: Bool
    ) {
        guard let index = textureLayers.getIndex(layer: layer) else { return }

        textureLayers.updateLayer(
            index: index,
            isVisible: isVisible
        )

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
    }
    func didChangeLayerAlpha(
        layer: TextureLayer,
        value: Int
    ) {
        guard let index = textureLayers.getIndex(layer: layer) else { return }

        textureLayers.updateLayer(
            index: index,
            alpha: value
        )

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            on: canvasView
        )
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
        textureLayerUndoManager.addCurrentLayersToUndoStack()

        textureLayers.moveLayer(
            fromOffsets: source,
            toOffset: destination
        )

        displayCanvasTextureWithMergedLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            isUnselectedLayerMergeNeeded: true,
            on: canvasView
        )
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
