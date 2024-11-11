//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

final class CanvasViewModel {

    let textureLayers = TextureLayers()

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

    private var drawingCurvePoints: CanvasDrawingCurvePoints?

    private let transformer = CanvasTransformer()

    private var drawingDisplayLink: CADisplayLink?

    /// A dictionary for handling finger input values
    private let fingerDrawingDictionary = CanvasFingerDrawingDictionary()

    /// Arrays for handling Apple Pencil input values
    private let pencilDrawingArrays = CanvasPencilDrawingArrays()

    private let inputDevice = CanvasInputDeviceStatus()

    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private var localRepository: LocalRepository?

    private var canvasView: CanvasViewProtocol?

    private let textureLayerUndoManager = TextureLayerUndoManager()

    /// A texture with a background color, composed of `drawingTexture` and `currentTexture`
    private var canvasTexture: MTLTexture?

    /// A texture that combines the texture of the currently selected `TextureLayer` and `drawingTexture`
    private var currentTexture: MTLTexture?

    /// A protocol for managing current drawing texture
    private var currentDrawingTexture: CanvasDrawingTexture?
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

    private let runDisplayLinkSubject = PassthroughSubject<Bool, Never>()

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
                    self.currentDrawingTexture = self.brushDrawingTexture
                case .eraser:
                    self.currentDrawingTexture = self.eraserDrawingTexture
                }
            }
            .store(in: &cancellables)

        runDisplayLinkSubject
            .map { !$0 }
            .sink { [weak self] isPause in
                self?.drawingDisplayLink?.isPaused = isPause
            }
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)
    }

    private func setupDisplayLink() {
        // Configure the display link for rendering
        drawingDisplayLink = CADisplayLink(target: self, selector: #selector(updateCanvasViewWhileDrawing))
        drawingDisplayLink?.add(to: .current, forMode: .common)
        drawingDisplayLink?.isPaused = true
    }

    func setCanvasView(_ canvasView: CanvasViewProtocol) {
        self.canvasView = canvasView
    }

    func initCanvas(size: CGSize) {
        guard let device else { return }

        brushDrawingTexture.initTexture(size)
        eraserDrawingTexture.initTexture(size)

        textureLayers.initLayers(size: size)

        currentTexture = MTLTextureCreator.makeTexture(size: size, with: device)

        canvasTexture = MTLTextureCreator.makeTexture(size: size, with: device)
    }

    func apply(model: CanvasModel) {
        guard 
            let device,
            let canvasView
        else { return }

        projectName = model.projectName

        textureLayerUndoManager.reset()

        brushDrawingTexture.initTexture(model.textureSize)
        eraserDrawingTexture.initTexture(model.textureSize)

        textureLayers.initLayers(
            newLayers: model.layers,
            layerIndex: model.layerIndex,
            size: model.textureSize
        )

        for i in 0 ..< textureLayers.layers.count {
            textureLayers.layers[i].updateThumbnail()
        }

        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        currentTexture = MTLTextureCreator.makeTexture(size: model.textureSize, with: device)

        canvasTexture = MTLTextureCreator.makeTexture(size: model.textureSize, with: device)

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
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

        MTLRenderer.clearTexture(texture: currentTexture, with: commandBuffer)

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
            on: canvasView
        )
    }

}

extension CanvasViewModel {

    func onUpdateRenderTexture() {
        guard let canvasView else { return }

        // Initialize the canvas here if `canvasTexture` is nil
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(size: textureSize)
        }

        // Redraws the canvas when the device rotates and the canvas size changes.
        updateCanvasViewWithTextureLayers(
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
            initCanvas(size: textureSize)
        }

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            on: canvasView
        )

        // Update the display of the Undo and Redo buttons
        textureLayerUndoManager.updateUndoComponents()
    }

    /// Manages all finger positions on the screen using a dictionary
    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        guard inputDevice.update(.finger) != .pencil else { return }

        var dictionary: [CanvasTouchHashValue: CanvasTouchPoint] = [:]
        UITouch.getFingerTouches(event: event).forEach { touch in
            dictionary[touch.hashValue] = .init(touch: touch, view: view)
        }
        fingerDrawingDictionary.appendTouches(dictionary)

        // determine the gesture from the dictionary, and based on that, either draw a line on the canvas or transform the canvas
        switch screenTouchGesture.update(
            .init(from: fingerDrawingDictionary.touchArrayDictionary)
        ) {
        case .drawing:
            if !(drawingCurvePoints is CanvasFingerDrawingCurvePoints) {
                drawingCurvePoints = CanvasFingerDrawingCurvePoints()
            }
            if fingerDrawingDictionary.dictionaryKey == nil {
                fingerDrawingDictionary.dictionaryKey = fingerDrawingDictionary.touchArrayDictionary.keys.first
            }
            guard 
                let drawingCurvePoints,
                let key = fingerDrawingDictionary.dictionaryKey,
                let screenTouchPoints = fingerDrawingDictionary.getLatestTouchPoints(for: key)
            else { return }

            let touchPhase = screenTouchPoints.currentTouchPhase

            // Convert screen scale points to texture scale
            let textureDotPoints: [CanvasGrayscaleDotPoint] = screenTouchPoints.compactMap {
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

            drawingCurvePoints.appendToIterator(
                points: textureDotPoints,
                touchPhase: touchPhase
            )

            runDrawingDisplayLinkToUpdateCanvasView(!drawingCurvePoints.isDrawingFinished)

        case .transforming:
            if transformer.isCurrentKeysNil {
                transformer.initTransforming(fingerDrawingDictionary.touchArrayDictionary)
            }

            if !fingerDrawingDictionary.hasFingersLiftedOffScreen {
                transformer.transformCanvas(
                    screenCenter: .init(
                        x: frameSize.width * 0.5,
                        y: frameSize.height * 0.5
                    ),
                    fingerDrawingDictionary.touchArrayDictionary
                )
            } else {
                transformer.finishTransforming()
            }

            updateCanvasWithTexture(canvasTexture, on: canvasView)

        default:
            break
        }

        fingerDrawingDictionary.removeIfLastElementMatches(phases: [.ended, .cancelled])

        if fingerDrawingDictionary.isEmpty && isAllFingersReleasedFromScreen(touches: touches, with: event) {
            resetAllInputParameters()
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

        // Make `drawingCurvePoints` and reset the parameters when a touch begins
        if estimatedTouches.contains(where: {$0.phase == .began}) {
            drawingCurvePoints = CanvasPencilDrawingCurvePoints()
            pencilDrawingArrays.reset()
        }

        // Append estimated values to the array
        event?.allTouches?
            .compactMap { $0.type == .pencil ? $0 : nil }
            .sorted { $0.timestamp < $1.timestamp }
            .forEach { touch in
                event?.coalescedTouches(for: touch)?.forEach { coalescedTouch in
                    pencilDrawingArrays.appendEstimatedValue(
                        .init(touch: coalescedTouch, view: view)
                    )
                }
            }
    }

    func onPencilGestureDetected(
        actualTouches: Set<UITouch>,
        view: UIView
    ) {
        guard let drawingCurvePoints else { return }

        // Combine `actualTouches` with the estimated values to create actual values, and append them to an array
        Array(actualTouches).sorted { $0.timestamp < $1.timestamp }.forEach { actualTouch in
            pencilDrawingArrays.appendActualTouchWithEstimatedValue(actualTouch)
        }

        let screenTouchPoints = pencilDrawingArrays.getLatestActualTouchPoints()

        let touchPhase = screenTouchPoints.currentTouchPhase

        // Convert screen scale points to texture scale
        let textureDotPoints: [CanvasGrayscaleDotPoint] = screenTouchPoints.compactMap {
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

        drawingCurvePoints.appendToIterator(
            points: textureDotPoints,
            touchPhase: touchPhase
        )

        runDrawingDisplayLinkToUpdateCanvasView(!drawingCurvePoints.isDrawingFinished)
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
        transformer.setMatrix(.identity)

        updateCanvasWithTexture(canvasTexture, on: canvasView)
    }

    func didTapNewCanvasButton() {
        guard
            let size = canvasTexture?.size,
            let canvasView
        else { return }

        projectName = Calendar.currentDate

        transformer.setMatrix(.identity)

        textureLayerUndoManager.reset()

        initCanvas(size: size)

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
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

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
            on: canvasView
        )
    }
    func didTapAddLayerButton() {
        guard
            let device,
            let renderTextureSize = canvasView?.renderTexture?.size,
            let newTexture = MTLTextureCreator.makeBlankTexture(
                size: renderTextureSize,
                with: device
            )
        else { return }

        textureLayerUndoManager.addCurrentLayersToUndoStack()

        let layer: TextureLayer = .init(
            texture: newTexture,
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
        textureLayers.addLayer(layer)

        // Makes a thumbnail
        if let index = textureLayers.getIndex(layer: layer) {
            textureLayers.updateThumbnail(index: index)
        }

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
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

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
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

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
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

        updateCanvasViewWithTextureLayers(
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

        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            shouldUpdateAllLayers: true,
            on: canvasView
        )
    }

}

extension CanvasViewModel {

    @objc private func updateCanvasViewWhileDrawing() {
        guard
            let drawingCurvePoints,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        // Draw curve points on `drawingTexture`
        if let textureCurvePoints = drawingCurvePoints.makeCurvePointsFromIterator() {
            if let currentDrawingTexture = currentDrawingTexture as? CanvasEraserDrawingTexture,
               let selectedLayerTexture = textureLayers.selectedLayer?.texture {
                currentDrawingTexture.drawPointsOnEraserDrawingTexture(
                    points: textureCurvePoints,
                    alpha: drawingTool.eraserAlpha,
                    srcTexture: selectedLayerTexture,
                    with: commandBuffer
                )
            } else if let currentDrawingTexture = currentDrawingTexture as? CanvasBrushDrawingTexture {
                currentDrawingTexture.drawPointsOnBrushDrawingTexture(
                    points: textureCurvePoints,
                    color: drawingTool.brushColor,
                    with: commandBuffer
                )
            }
        }

        // Draw `selectedLayer.texture` and `drawingTexture` onto currentTexture
        currentDrawingTexture?.renderDrawingTexture(
            withSelectedTexture: textureLayers.selectedLayer?.texture,
            onto: currentTexture,
            with: commandBuffer
        )

        if drawingCurvePoints.isDrawingFinished {
            // Add `textureLayer` to the undo stack
            // when the drawing is ended and before `DrawingTexture` is merged with `selectedLayer.texture`
            textureLayerUndoManager.addCurrentLayersToUndoStack()

            // Draw `drawingTexture` onto `selectedLayer.texture`
            currentDrawingTexture?.mergeDrawingTexture(
                into: textureLayers.selectedLayer?.texture,
                with: commandBuffer
            )

            resetAllInputParameters()
        }

        if requestShowingLayerViewSubject.value && drawingCurvePoints.isDrawingComplete {
            updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
        }

        // Update `canvasView` with `canvasTexture`
        updateCanvasViewWithTextureLayers(
            textureLayers: textureLayers,
            usingCurrentTexture: currentTexture,
            canvasTexture: canvasTexture,
            canvasTextureBackgroundColor: drawingTool.backgroundColor,
            on: canvasView
        )
    }

    private func updateCanvasViewWithTextureLayers(
        textureLayers: TextureLayers,
        usingCurrentTexture: MTLTexture? = nil,
        canvasTexture: MTLTexture?,
        canvasTextureBackgroundColor: UIColor,
        shouldUpdateAllLayers: Bool = false,
        on canvasView: CanvasViewProtocol?
    ) {
        guard let commandBuffer = canvasView?.commandBuffer else { return }

        textureLayers.mergeAllTextures(
            usingCurrentTexture: usingCurrentTexture,
            shouldUpdateAllLayers: shouldUpdateAllLayers,
            backgroundColor: canvasTextureBackgroundColor,
            on: canvasTexture,
            with: commandBuffer
        )

        updateCanvasWithTexture(canvasTexture, on: canvasView)
    }

    private func updateCanvasWithTexture(
        _ texture: MTLTexture?,
        on canvasView: CanvasViewProtocol?
    ) {
        guard
            let device,
            let sourceTexture = texture,
            let destinationTexture = canvasView?.renderTexture,
            let sourceTextureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                matrix: transformer.matrix,
                frameSize: frameSize,
                sourceSize: .init(
                    width: sourceTexture.size.width * ViewSize.getScaleToFit(sourceTexture.size, to: destinationTexture.size),
                    height: sourceTexture.size.height * ViewSize.getScaleToFit(sourceTexture.size, to: destinationTexture.size)
                ),
                destinationSize: destinationTexture.size,
                with: device
            ),
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        MTLRenderer.drawTexture(
            texture: sourceTexture,
            buffers: sourceTextureBuffers,
            withBackgroundColor: UIColor(rgb: Constants.blankAreaBackgroundColor),
            on: destinationTexture,
            with: commandBuffer
        )

        canvasView?.setNeedsDisplay()
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

}

extension CanvasViewModel {
    /// Starts or stops the display link loop
    private func runDrawingDisplayLinkToUpdateCanvasView(_ isRunning: Bool) {
        runDisplayLinkSubject.send(isRunning)

        // Update `CanvasView` when stopping as the last line isn’t drawn
        if !isRunning {
            updateCanvasViewWhileDrawing()
        }
    }

    private func isAllFingersReleasedFromScreen(
        touches: Set<UITouch>,
        with event: UIEvent?
    ) -> Bool {
        touches.count == event?.allTouches?.count &&
        touches.contains { $0.phase == .ended || $0.phase == .cancelled }
    }

    private func resetAllInputParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        fingerDrawingDictionary.reset()
        pencilDrawingArrays.reset()

        drawingCurvePoints = nil
        transformer.reset()
    }

    private func cancelFingerInput() {
        fingerDrawingDictionary.reset()

        currentDrawingTexture?.clearAllTextures()

        drawingCurvePoints = nil
        transformer.reset()

        canvasView?.resetCommandBuffer()

        updateCanvasWithTexture(canvasTexture, on: canvasView)
    }

}

extension CanvasViewModel {

    private func convertScreenTouchPointToTextureDotPoint(
        touchPoint: CanvasTouchPoint,
        textureSize: CGSize,
        drawableSize: CGSize
    ) -> CanvasGrayscaleDotPoint {

        let textureMatrix = convertScreenMatrixToTextureMatrix(
            matrix: transformer.matrix.inverted(flipY: true),
            drawableSize: drawableSize,
            textureSize: textureSize
        )
        let textureLocation = convertScreenLocationToTextureLocation(
            touchLocation: touchPoint.location,
            frameSize: frameSize,
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

    private func convertScreenMatrixToTextureMatrix(
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

    private func convertScreenLocationToTextureLocation(
        touchLocation: CGPoint,
        frameSize: CGSize,
        drawableSize: CGSize,
        textureSize: CGSize
    ) -> CGPoint {
        if textureSize != drawableSize {
            let drawableToTextureFillScale = ViewSize.getScaleToFill(drawableSize, to: textureSize)
            let drawableLocation: CGPoint = .init(
                x: touchLocation.x * (drawableSize.width / frameSize.width),
                y: touchLocation.y * (drawableSize.width / frameSize.width)
            )
            return .init(
                x: drawableLocation.x * drawableToTextureFillScale + (textureSize.width - drawableSize.width * drawableToTextureFillScale) * 0.5,
                y: drawableLocation.y * drawableToTextureFillScale + (textureSize.height - drawableSize.height * drawableToTextureFillScale) * 0.5
            )
        } else {
            return .init(
                x: touchLocation.x * (textureSize.width / frameSize.width),
                y: touchLocation.y * (textureSize.width / frameSize.width)
            )
        }
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
