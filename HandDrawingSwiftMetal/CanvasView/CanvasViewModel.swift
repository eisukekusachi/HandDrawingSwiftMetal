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

    var updateUndoButtonIsEnabledState: AnyPublisher<Bool, Never> {
        updateUndoButtonIsEnabledStateSubject.eraseToAnyPublisher()
    }
    var updateRedoButtonIsEnabledState: AnyPublisher<Bool, Never> {
        updateRedoButtonIsEnabledStateSubject.eraseToAnyPublisher()
    }

    var isLayerViewVisible: Bool {
        requestShowingLayerViewSubject.value
    }

    private var drawingCurvePoints: CanvasDrawingCurvePoints?

    private let transformer = CanvasTransformer()

    /// A dictionary for handling finger input values
    private let fingerDrawingDictionary = CanvasFingerDrawingDictionary()

    /// Arrays for handling Apple Pencil input values
    private let pencilDrawingArrays = CanvasPencilDrawingArrays()

    private let inputDevice = CanvasInputDeviceStatus()

    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private var localRepository: LocalRepository?

    private var drawingDisplayLink = CanvasDrawingDisplayLink()

    private var canvasView: CanvasViewProtocol?

    /// A texture with a background color, composed of `drawingTexture` and `currentTexture`
    private var canvasTexture: MTLTexture?

    /// A texture that combines the texture of the currently selected `TextureLayer` and `drawingTexture`
    private var currentTexture: MTLTexture?

    /// A protocol for real-time drawing on a texture
    private var drawingTexture: CanvasDrawingTexture?
    /// A drawing texture with a brush
    private let brushDrawingTexture = CanvasBrushDrawingTexture(renderer: MTLRenderer.shared)
    /// A drawing texture with an eraser
    private let eraserDrawingTexture = CanvasEraserDrawingTexture(renderer: MTLRenderer.shared)

    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let requestShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private let refreshCanvasSubject = PassthroughSubject<CanvasModel, Never>()

    private let updateUndoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    private let updateRedoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        localRepository: LocalRepository = DocumentsLocalRepository()
    ) {
        self.localRepository = localRepository

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

        drawingTool.brushColorPublisher
            .sink { [weak self] color in
                self?.brushDrawingTexture.setBlushColor(color)
            }
            .store(in: &cancellables)

        drawingTool.eraserAlphaPublisher
            .sink { [weak self] alpha in
                self?.eraserDrawingTexture.setEraserAlpha(alpha)
            }
            .store(in: &cancellables)

        Publishers.Merge(
            brushDrawingTexture.drawingFinishedPublisher,
            eraserDrawingTexture.drawingFinishedPublisher
        )
            .sink { [weak self] in
                guard let `self` else { return }
                self.resetAllInputParameters()

                // Update the thumbnail when the layerView is visible
                if self.isLayerViewVisible {
                    DispatchQueue.main.async { [weak self] in
                        self?.updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: 1000_000)
                    }
                }
            }
            .store(in: &cancellables)

        drawingDisplayLink.requestDrawingOnCanvasPublisher
            .sink { [weak self] in
                self?.updateCanvasWithDrawing()
            }
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)
    }

    func setCanvasView(_ canvasView: CanvasViewProtocol) {
        self.canvasView = canvasView
    }

    func initCanvas(size: CGSize) {
        brushDrawingTexture.initTextures(size)
        eraserDrawingTexture.initTextures(size)

        textureLayers.initLayers(size: size)

        currentTexture = MTLTextureCreator.makeTexture(size: size, with: device)

        canvasTexture = MTLTextureCreator.makeTexture(size: size, with: device)
    }

    func apply(model: CanvasModel) {
        guard let canvasView else { return }

        projectName = model.projectName

        brushDrawingTexture.initTextures(model.textureSize)
        eraserDrawingTexture.initTextures(model.textureSize)

        textureLayers.initLayers(
            size: model.textureSize,
            layers: model.layers,
            layerIndex: model.layerIndex
        )

        for i in 0 ..< textureLayers.layers.count {
            textureLayers.layers[i].updateThumbnail()
        }

        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        currentTexture = MTLTextureCreator.makeTexture(size: model.textureSize, with: device)

        canvasTexture = MTLTextureCreator.makeTexture(size: model.textureSize, with: device)

        updateCanvasView(allLayerUpdates: true)
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
        updateCanvasView(allLayerUpdates: true)
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

        updateCanvasView(allLayerUpdates: true)
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
                    matrix: transformer.matrix.inverted(flipY: true),
                    touchPoint: $0,
                    textureSize: textureSize,
                    drawableSize: drawableSize
                )
            }

            drawingCurvePoints.appendToIterator(
                points: textureDotPoints,
                touchPhase: touchPhase
            )

            drawingDisplayLink.runDisplayLink(
                isCurrentlyDrawing: drawingCurvePoints.isCurrentlyDrawing
            )

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

            guard
                let renderTexture = canvasView?.renderTexture,
                let commandBuffer = canvasView?.commandBuffer
            else { return }

            drawTexture(
                texture: canvasTexture,
                matrix: transformer.matrix,
                on: renderTexture,
                with: commandBuffer
            )
            canvasView?.setNeedsDisplay()

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
                matrix: transformer.matrix.inverted(flipY: true),
                touchPoint: $0,
                textureSize: textureSize,
                drawableSize: drawableSize
            )
        }

        drawingCurvePoints.appendToIterator(
            points: textureDotPoints,
            touchPhase: touchPhase
        )

        drawingDisplayLink.runDisplayLink(
            isCurrentlyDrawing: drawingCurvePoints.isCurrentlyDrawing
        )
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {}
    func didTapRedoButton() {}

    func didTapLayerButton() {
        textureLayers.updateThumbnail(index: textureLayers.index)
        requestShowingLayerViewSubject.send(!requestShowingLayerViewSubject.value)
    }

    func didTapResetTransformButton() {
        transformer.setMatrix(.identity)

        guard
            let renderTexture = canvasView?.renderTexture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        drawTexture(
            texture: canvasTexture,
            matrix: transformer.matrix,
            on: renderTexture,
            with: commandBuffer
        )
        canvasView?.setNeedsDisplay()
    }

    func didTapNewCanvasButton() {
        guard
            let size = canvasTexture?.size,
            let canvasView
        else { return }

        projectName = Calendar.currentDate

        transformer.setMatrix(.identity)

        initCanvas(size: size)

        updateCanvasView(allLayerUpdates: true)
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        guard let canvasTexture else { return }
        saveFile(canvasTexture: canvasTexture)
    }

    // MARK: Layers
    func didTapLayer(layer: TextureLayer) {
        guard let index = textureLayers.getIndex(layer: layer)  else { return }

        textureLayers.index = index

        updateCanvasView(allLayerUpdates: true)
    }
    func didTapAddLayerButton() {
        guard
            let renderTextureSize = canvasView?.renderTexture?.size,
            let newTexture = MTLTextureCreator.makeBlankTexture(
                size: renderTextureSize,
                with: device
            )
        else { return }

        let layer: TextureLayer = .init(
            texture: newTexture,
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
        let index = textureLayers.index + 1
        textureLayers.insertLayer(
            layer: layer,
            at: index
        )
        textureLayers.setIndex(from: layer)

        // Makes a thumbnail
        textureLayers.updateThumbnail(index: index)

        updateCanvasView(allLayerUpdates: true)
    }
    func didTapRemoveLayerButton() {
        guard
            textureLayers.canDeleteLayer,
            let layer = textureLayers.selectedLayer,
            let index = textureLayers.getIndex(layer: layer)
        else { return }

        textureLayers.removeLayer(layer)
        textureLayers.setIndex(index - 1)

        updateCanvasView(allLayerUpdates: true)
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

        updateCanvasView(allLayerUpdates: true)
    }
    func didStartChangingLayerAlpha(layer: TextureLayer) {}
    func didChangeLayerAlpha(
        layer: TextureLayer,
        value: Int
    ) {
        guard let index = textureLayers.getIndex(layer: layer) else { return }

        textureLayers.updateLayer(
            index: index,
            alpha: value
        )

        updateCanvasView()
    }
    func didFinishChangingLayerAlpha(layer: TextureLayer) {}

    func didEditLayerTitle(
        layer: TextureLayer,
        title: String
    ) {
        guard let index = textureLayers.getIndex(layer: layer) else { return }

        textureLayers.updateLayer(
            index: index,
            title: title
        )
    }

    func didMoveLayers(
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        let listFromIndex = fromOffsets.first ?? 0
        let listToIndex = toOffset

        // Convert the value received from `onMove(perform:)` into a value used in an array
        let listSource = listFromIndex
        let listDestination = UndoMoveData.getMoveDestination(fromIndex: listFromIndex, toIndex: listToIndex)

        let textureLayerSource = TextureLayers.getReversedIndex(
            index: listSource,
            layerCount: textureLayers.count
        )
        let textureLayerDestination = TextureLayers.getReversedIndex(
            index: listDestination,
            layerCount: textureLayers.count
        )

        let textureLayerSelectedIndex = textureLayers.index
        let textureLayerSelectedIndexAfterMove = UndoMoveData.makeSelectedIndexAfterMove(
            source: textureLayerSource,
            destination: textureLayerDestination,
            selectedIndex: textureLayerSelectedIndex
        )

        textureLayers.moveLayer(
            fromListOffsets: fromOffsets,
            toListOffset: toOffset
        )
        textureLayers.setIndex(textureLayerSelectedIndexAfterMove)

        updateCanvasView(allLayerUpdates: true)
    }

}

extension CanvasViewModel {

    private func drawTexture(
        texture: MTLTexture?,
        matrix: CGAffineTransform,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let textureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                matrix: matrix,
                frameSize: frameSize,
                sourceSize: .init(
                    width: texture.size.width * ViewSize.getScaleToFit(texture.size, to: destinationTexture.size),
                    height: texture.size.height * ViewSize.getScaleToFit(texture.size, to: destinationTexture.size)
                ),
                destinationSize: destinationTexture.size,
                with: device
            )
        else { return }

        MTLRenderer.shared.drawTexture(
            texture: texture,
            buffers: textureBuffers,
            withBackgroundColor: UIColor(rgb: Constants.blankAreaBackgroundColor),
            on: destinationTexture,
            with: commandBuffer
        )
    }

    private func updateCanvasView(allLayerUpdates: Bool = false) {
        guard
            let renderTexture = canvasView?.renderTexture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        textureLayers.drawAllTextures(
            withAllLayerUpdates: allLayerUpdates,
            backgroundColor: drawingTool.backgroundColor,
            on: canvasTexture,
            with: commandBuffer
        )

        drawTexture(
            texture: canvasTexture,
            matrix: transformer.matrix,
            on: renderTexture,
            with: commandBuffer
        )

        canvasView?.setNeedsDisplay()
    }

    private func updateCanvasWithDrawing() {
        guard
            let drawingCurvePoints,
            let currentTexture,
            let selectedTexture = textureLayers.selectedLayer?.texture,
            let renderTexture = canvasView?.renderTexture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        drawingTexture?.drawCurvePointsUsingSelectedTexture(
            drawingCurvePoints: drawingCurvePoints,
            selectedTexture: selectedTexture,
            on: currentTexture,
            with: commandBuffer
        )

        textureLayers.drawAllTextures(
            usingCurrentTexture: currentTexture,
            backgroundColor: drawingTool.backgroundColor,
            on: canvasTexture,
            with: commandBuffer
        )

        drawTexture(
            texture: canvasTexture,
            matrix: transformer.matrix,
            on: renderTexture,
            with: commandBuffer
        )

        canvasView?.setNeedsDisplay()
    }

    /// Makes a thumbnail with a slight delay to allow processing after the Metal command buffer has completed
    @MainActor
    private func updateCurrentLayerThumbnailWithDelay(nanosecondsDuration: UInt64) {
        Task { [weak self] in
            guard let self else { return }
            try await Task.sleep(nanoseconds: nanosecondsDuration)
            self.textureLayers.updateThumbnail(index: self.textureLayers.index)
        }
    }

}

extension CanvasViewModel {

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

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTexture?.clearDrawingTextures(with: commandBuffer)
        commandBuffer.commit()

        drawingCurvePoints = nil
        transformer.reset()

        canvasView?.resetCommandBuffer()

        guard
            let renderTexture = canvasView?.renderTexture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        drawTexture(
            texture: canvasTexture,
            matrix: transformer.matrix,
            on: renderTexture,
            with: commandBuffer
        )
        canvasView?.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    private func convertScreenTouchPointToTextureDotPoint(
        matrix: CGAffineTransform,
        touchPoint: CanvasTouchPoint,
        textureSize: CGSize,
        drawableSize: CGSize
    ) -> CanvasGrayscaleDotPoint {

        let textureMatrix = convertScreenMatrixToTextureMatrix(
            matrix: matrix,
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

    private func saveFile(canvasTexture: MTLTexture) {
        localRepository?.saveDataToDocuments(
            renderTexture: canvasTexture,
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
