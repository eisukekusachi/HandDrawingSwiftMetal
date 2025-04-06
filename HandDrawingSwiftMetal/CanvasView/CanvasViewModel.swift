//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import SwiftUI
import Combine

final class MockTextureRepository: TextureRepository {

    var textures: [UUID: MTLTexture?] = [:]

    var callHistory: [String] = []

    var textureNum: Int = 0

    init(textures: [UUID : MTLTexture?] = [:]) {
        self.textures = textures
    }

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error> {
        callHistory.append("hasAllTextures(for: \(uuids.map { $0.uuidString }))")
        return Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        callHistory.append("initTexture(uuid: \(uuid), textureSize: \(textureSize))")
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error> {
        callHistory.append("initTextures(layers: \(layers.count), textureSize: \(textureSize), folderURL: \(folderURL.lastPathComponent))")
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        callHistory.append("getThumbnail(\(uuid))")
        return nil
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<MTLTexture?, Error> {
        callHistory.append("loadTexture(\(uuid))")
        let resultTexture: MTLTexture? = textures[uuid]?.flatMap { $0 }
        return Just(resultTexture)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID: MTLTexture?], Error> {
        callHistory.append("loadTextures(\(uuids.count) uuids)")
        return Just(
            uuids.reduce(into: [:]) { dict, uuid in
                dict[uuid] = textures[uuid] ?? nil
            }
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        callHistory.append("removeTexture(\(uuid))")
        return Just(uuid)
            .eraseToAnyPublisher()
    }

    func removeAll() {
        callHistory.append("removeAll()")
    }

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        callHistory.append("setThumbnail(texture: \(texture?.label ?? "nil"), for: \(uuid))")
    }

    func setAllThumbnails() {
        callHistory.append("setAllThumbnails()")
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}

final class MockMTLRenderer: MTLRendering {

    var callHistory: [String] = []

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: HandDrawingSwiftMetal.MTLGrayscalePointBuffers?,
        onGrayscaleTexture texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawGrayPointBuffersWithMaxBlendMode(",
                "buffers: buffers, ",
                "onGrayscaleTexture: \(textureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func drawTexture(
        texture: MTLTexture,
        buffers: HandDrawingSwiftMetal.MTLTextureBuffers,
        withBackgroundColor color: UIColor?,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawTexture(",
                "texture: \(textureLabel), ",
                "buffers: buffers, ",
                "withBackgroundColor: \(color?.rgba ?? (0, 0, 0, 0)), ",
                "on: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: (Int, Int, Int),
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let grayscaleTextureLabel = grayscaleTexture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawTexture(",
                "grayscaleTexture: \(grayscaleTextureLabel), ",
                "color: \(rgb), ",
                "on: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func subtractTextureWithEraseBlendMode(
        texture: any MTLTexture,
        buffers: MTLTextureBuffers,
        from destinationTexture: any MTLTexture,
        with commandBuffer: any MTLCommandBuffer
    ) {
        let sourceTexture = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "subtractTextureWithEraseBlendMode(",
                "texture: \(sourceTexture), ",
                "buffers: buffers, ",
                "from: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func fillTexture(
        texture: MTLTexture,
        withRGB rgb: (Int, Int, Int),
        with commandBuffer: any MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "fillTexture(",
                "texture: \(textureLabel), ",
                "withRGB: \(rgb), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func fillTexture(
        texture: MTLTexture,
        withRGBA rgba: (Int, Int, Int, Int),
        with commandBuffer: any MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "fillTexture(",
                "texture: \(textureLabel), ",
                "withRGBA: \(rgba), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func mergeTexture(
        texture: MTLTexture,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let sourceTexture = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "mergeTexture(",
                "texture: \(sourceTexture), ",
                "into: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let sourceTexture = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "mergeTexture(",
                "texture: \(sourceTexture), ",
                "alpha: \(alpha), ",
                "into: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func clearTextures(
        textures: [(any MTLTexture)?],
        with commandBuffer: any MTLCommandBuffer
    ) {
        let textureLabels = textures.compactMap { $0?.label }.joined(separator: ", ")
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "clearTextures(",
                "textures: [\(textureLabels)], ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "clearTexture(",
                "texture: \(textureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

}


final class CanvasViewModel {
    var frameSize: CGSize = .zero {
        didSet {
            renderer.frameSize = frameSize
        }
    }

    let textureLayers = TextureLayers()

    let drawingTool = CanvasDrawingToolStatus()

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var requestShowingActivityIndicatorPublisher: AnyPublisher<Bool, Never> {
        requestShowingActivityIndicatorSubject.eraseToAnyPublisher()
    }
    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    var requestShowingAlertPublisher: AnyPublisher<String, Never> {
        requestShowingAlertSubject.eraseToAnyPublisher()
    }
    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    var requestShowingToastPublisher: AnyPublisher<ToastModel, Never> {
        requestShowingToastSubject.eraseToAnyPublisher()
    }
    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    var requestShowingLayerViewPublisher: AnyPublisher<Bool, Never> {
        requestShowingLayerViewSubject.eraseToAnyPublisher()
    }
    private let requestShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    var refreshCanvasPublisher: AnyPublisher<CanvasModel, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }
    private let refreshCanvasSubject = PassthroughSubject<CanvasModel, Never>()

    var updateUndoButtonIsEnabledState: AnyPublisher<Bool, Never> {
        updateUndoButtonIsEnabledStateSubject.eraseToAnyPublisher()
    }
    var updateRedoButtonIsEnabledState: AnyPublisher<Bool, Never> {
        updateRedoButtonIsEnabledStateSubject.eraseToAnyPublisher()
    }
    private let updateUndoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()
    private let updateRedoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    var isLayerViewVisible: Bool {
        requestShowingLayerViewSubject.value
    }

    /// A class for handling finger input values
    private let fingerScreenStrokeData = FingerScreenStrokeData()
    /// A class for handling Apple Pencil inputs
    private let pencilScreenStrokeData = PencilScreenStrokeData()

    /// An iterator for real-time drawing
    private var drawingCurveIterator: DrawingCurveIterator?

    /// A texture set for real-time drawing
    private var drawingTextureSet: CanvasDrawingTextureSet?
    /// A brush texture set for real-time drawing
    private let drawingBrushTextureSet = CanvasDrawingBrushTextureSet()
    /// An eraser texture set for real-time drawing
    private let drawingEraserTextureSet = CanvasDrawingEraserTextureSet()

    /// A display link for real-time drawing
    private var drawingDisplayLink = CanvasDrawingDisplayLink()

    private var renderer = CanvasRenderer()

    private let transformer = CanvasTransformer()

    private let inputDevice = CanvasInputDeviceStatus()

    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private var textureRepository: TextureRepository?

    private var localRepository: LocalRepository?

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        textureRepository: TextureRepository? = SingletonTextureInMemoryRepository.shared,
        localRepository: LocalRepository = DocumentsLocalRepository()
    ) {
        self.textureRepository = textureRepository
        self.localRepository = localRepository

        drawingTool.setDrawingTool(.brush)

        subscribe()
    }

    private func subscribe() {
        drawingDisplayLink.canvasDrawingPublisher
            .sink { [weak self] in
                self?.updateCanvasWithLine()
            }
            .store(in: &cancellables)

        Publishers.Merge(
            drawingBrushTextureSet.canvasDrawFinishedPublisher,
            drawingEraserTextureSet.canvasDrawFinishedPublisher
        )
        .sink { [weak self] in
            self?.completeCanvasUpdateWithLine()
        }
        .store(in: &cancellables)

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                guard let `self` else { return }
                switch tool {
                case .brush: self.drawingTextureSet = self.drawingBrushTextureSet
                case .eraser: self.drawingTextureSet = self.drawingEraserTextureSet
                }
            }
            .store(in: &cancellables)

        drawingTool.brushColorPublisher
            .sink { [weak self] color in
                self?.drawingBrushTextureSet.setBlushColor(color)
            }
            .store(in: &cancellables)

        drawingTool.eraserAlphaPublisher
            .sink { [weak self] alpha in
                self?.drawingEraserTextureSet.setEraserAlpha(alpha)
            }
            .store(in: &cancellables)

        drawingTool.backgroundColorPublisher
            .assign(to: \.backgroundColor, on: renderer)
            .store(in: &cancellables)

        textureLayers.didFinishInitializationPublisher
            .sink { [weak self] textureSize in
                self?.initTextures(textureSize: textureSize)
            }
            .store(in: &cancellables)

        textureLayers.updateCanvasAfterTextureLayerUpdatesPublisher
            .sink { [weak self] _ in
                guard let `self` else { return }
                self.renderer.updateCanvasAfterUpdatingAllTextures(
                    textureLayers: self.textureLayers,
                    commandBuffer: self.renderer.commandBuffer
                )
            }
            .store(in: &cancellables)

        textureLayers.updateCanvasPublisher
            .sink { [weak self] in
                self?.updateCanvas()
            }
            .store(in: &cancellables)

        transformer.matrixPublisher.assign(to: \.matrix, on: renderer) .store(in: &cancellables)
    }

    func initCanvas(using model: CanvasModel) {
        guard let drawableSize = renderer.renderTextureSize else { return }

        projectName = model.projectName
        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        textureLayers.restoreLayers(from: model, drawableSize: drawableSize)
    }

    private func initTextures(textureSize: CGSize) {
        guard let commandBuffer = renderer.commandBuffer else { return }

        drawingBrushTextureSet.initTextures(textureSize)
        drawingEraserTextureSet.initTextures(textureSize)

        renderer.initTextures(textureSize: textureSize)
        renderer.updateCanvasAfterUpdatingAllTextures(
            textureLayers: textureLayers,
            commandBuffer: commandBuffer
        )
    }

}

extension CanvasViewModel {

    func onViewDidLoad(
        canvasView: CanvasViewProtocol
    ) {
        renderer.setCanvas(canvasView)
    }

    func onViewDidAppear(
        model: CanvasModel,
        drawableTextureSize: CGSize
    ) {
        if !renderer.hasTextureBeenInitialized {
            initCanvas(using: model)
        }
    }

    func onUpdateRenderTexture() {
        // Redraws the canvas when the device rotates and the canvas size changes.
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        renderer.updateCanvas(
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        guard inputDevice.update(.finger) != .pencil else { return }

        fingerScreenStrokeData.appendTouchPointToDictionary(
            UITouch.getFingerTouches(event: event).reduce(into: [:]) {
                $0[$1.hashValue] = .init(touch: $1, view: view)
            }
        )

        // determine the gesture from the dictionary
        switch screenTouchGesture.update(fingerScreenStrokeData.touchArrayDictionary) {
        case .drawing:
            if shouldCreateFingerDrawingCurveIteratorInstance() {
                drawingCurveIterator = DrawingCurveFingerIterator()
            }

            fingerScreenStrokeData.setActiveDictionaryKeyIfNil()

            drawCurveOnCanvas(fingerScreenStrokeData.latestTouchPoints)

        case .transforming: transformCanvas()
        default: break
        }

        fingerScreenStrokeData.removeEndedTouchArrayFromDictionary()

        if UITouch.isAllFingersReleasedFromScreen(touches: touches, with: event) {
            resetAllInputParameters()
        }
    }

    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        // Cancel finger drawing and switch to pen drawing if present
        if inputDevice.status == .finger {
            cancelFingerDrawing()
        }
        inputDevice.update(.pencil)

        pencilScreenStrokeData.setLatestEstimatedTouchPoint(
            estimatedTouches
                .filter({ $0.type == .pencil })
                .sorted(by: { $0.timestamp < $1.timestamp })
                .last
                .map { .init(touch: $0, view: view) }
        )
    }

    func onPencilGestureDetected(
        actualTouches: Set<UITouch>,
        view: UIView
    ) {
        if shouldCreatePencilDrawingCurveIteratorInstance(actualTouches: actualTouches) {
            drawingCurveIterator = DrawingCurvePencilIterator()
        }

        pencilScreenStrokeData.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { TouchPoint(touch: $0, view: view) }
        )

        drawCurveOnCanvas(pencilScreenStrokeData.latestActualTouchPoints)
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {}
    func didTapRedoButton() {}

    func didTapLayerButton() {
        // Toggle the visibility of `TextureLayerView`
        requestShowingLayerViewSubject.send(!requestShowingLayerViewSubject.value)
    }

    func didTapResetTransformButton() {
        guard let commandBuffer = renderer.commandBuffer else { return }
        transformer.setMatrix(.identity)
        renderer.refreshCanvasView(commandBuffer)
    }

    func didTapNewCanvasButton() {
        transformer.setMatrix(.identity)
        initCanvas(
            using: .init(textureSize: renderer.textureSize)
        )
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        guard let canvasTexture = renderer.canvasTexture else { return }
        saveFile(canvasTexture: canvasTexture)
    }

    // MARK: Layers
    func didTapLayer(layer: TextureLayerModel) {
        textureLayers.selectLayer(layer.id)
    }
    func didTapAddLayerButton() {
        textureLayers.insertLayer(
            textureSize: renderer.textureSize,
            at: textureLayers.newIndex
        )
    }
    func didTapRemoveLayerButton() {
        textureLayers.removeLayer()
    }
    func didMoveLayers(fromOffsets: IndexSet, toOffset: Int) {
        textureLayers.moveLayer(fromListOffsets: fromOffsets, toListOffset: toOffset)
    }
    func didTapLayerVisibility(layer: TextureLayerModel, isVisible: Bool) {
        textureLayers.updateLayer(id: layer.id, isVisible: isVisible)
    }

    func didStartChangingLayerAlpha(layer: TextureLayerModel) {}

    func didChangeLayerAlpha(layer: TextureLayerModel, value: Int) {
        textureLayers.updateLayer(id: layer.id, alpha: value)
    }
    func didFinishChangingLayerAlpha(layer: TextureLayerModel) {}

    func didEditLayerTitle(layer: TextureLayerModel, title: String) {
        textureLayers.updateLayer(id: layer.id, title: title)
    }

}

extension CanvasViewModel {

    private func drawCurveOnCanvas(_ screenTouchPoints: [TouchPoint]) {
        guard let drawableSize = renderer.renderTextureSize else { return }

        drawingCurveIterator?.append(
            points: screenTouchPoints.map {
                .init(
                    matrix: transformer.matrix.inverted(flipY: true),
                    touchPoint: $0,
                    textureSize: renderer.textureSize,
                    drawableSize: drawableSize,
                    frameSize: renderer.frameSize,
                    diameter: CGFloat(drawingTool.diameter)
                )
            },
            touchPhase: screenTouchPoints.lastTouchPhase
        )

        drawingDisplayLink.updateCanvasWithDrawing(
            isCurrentlyDrawing: drawingCurveIterator?.isCurrentlyDrawing ?? false
        )
    }

    private func transformCanvas() {
        guard let commandBuffer = renderer.commandBuffer else { return }

        transformer.initTransformingIfNeeded(
            fingerScreenStrokeData.touchArrayDictionary
        )

        if fingerScreenStrokeData.isAllFingersOnScreen {
            transformer.transformCanvas(
                screenCenter: .init(
                    x: renderer.frameSize.width * 0.5,
                    y: renderer.frameSize.height * 0.5
                ),
                fingerScreenStrokeData.touchArrayDictionary
            )
        } else {
            transformer.finishTransforming()
        }

        renderer.refreshCanvasView(commandBuffer)
    }

}

extension CanvasViewModel {
    // Since the pencil takes priority, even if `drawingCurveIterator` contains an instance,
    // it will be overwritten when touchBegan occurs.
    private func shouldCreatePencilDrawingCurveIteratorInstance(actualTouches: Set<UITouch>) -> Bool {
        actualTouches.contains(where: { $0.phase == .began })
    }

    // If `drawingCurveIterator` is nil, an instance of `FingerDrawingCurveIterator` will be set.
    private func shouldCreateFingerDrawingCurveIteratorInstance() -> Bool {
        drawingCurveIterator == nil
    }

    private func resetAllInputParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        fingerScreenStrokeData.reset()
        pencilScreenStrokeData.reset()

        drawingCurveIterator = nil
        transformer.resetMatrix()
    }

    private func cancelFingerDrawing() {
        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTextureSet?.clearDrawingTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()

        fingerScreenStrokeData.reset()

        drawingCurveIterator = nil
        transformer.resetMatrix()

        renderer.resetCommandBuffer()

        if let commandBuffer = renderer.commandBuffer {
            renderer.refreshCanvasView(commandBuffer)
        }
    }

    private func updateCanvas() {
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        renderer.updateCanvas(
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

    private func updateCanvasWithLine() {
        guard
            let drawingCurveIterator,
            let selectedLayer = textureLayers.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        drawingTextureSet?.drawCurvePoints(
            drawingCurveIterator: drawingCurveIterator,
            withBackgroundTexture: self.renderer.selectedTexture,
            withBackgroundColor: .clear,
            with: commandBuffer
        )

        renderer.updateCanvas(
            realtimeDrawingTexture: self.drawingTextureSet?.drawingSelectedTexture,
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }
    private func completeCanvasUpdateWithLine() {
        resetAllInputParameters()

        renderer.commandBuffer?.addCompletedHandler { _ in
            DispatchQueue.main.async { [weak self] in
                guard
                    let selectedTexture = self?.renderer.selectedTexture,
                    let selectedTextureId = self?.textureLayers.selectedLayer?.id
                else { return }

                self?.renderer.renderTextureToLayerInRepository(
                    texture: selectedTexture,
                    targetTextureId: selectedTextureId
                ) { [weak self] texture in
                    self?.textureLayers.updateThumbnail(texture)
                }
            }
        }
    }

}

extension CanvasViewModel {

    private func loadFile(from filePath: String) {
        guard
            let localRepository,
            let textureRepository
        else { return }

        localRepository.loadDataFromDocuments(
            sourceURL: URL.documents.appendingPathComponent(filePath),
            textureRepository: textureRepository
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: { [weak self] canvasModel in
            self?.refreshCanvasSubject.send(canvasModel)
        })
        .store(in: &cancellables)
    }

    private func saveFile(canvasTexture: MTLTexture) {
        guard
            let localRepository,
            let textureRepository
        else { return }

        localRepository.saveDataToDocuments(
            renderTexture: canvasTexture,
            textureLayers: textureLayers,
            textureRepository: textureRepository,
            drawingTool: drawingTool,
            to: URL.getZipFileURL(projectName: projectName)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: {})
        .store(in: &cancellables)
    }

}
