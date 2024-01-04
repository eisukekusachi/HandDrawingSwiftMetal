//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

class CanvasViewModel {

    /// The currently selected drawing tool, either brush or eraser.
    @Published var drawingTool: DrawingToolType = .brush

    /// Drawing with a brush
    var drawingBrush = DrawingBrush()

    /// Drawing with an eraser
    var drawingEraser = DrawingEraser()

    /// A texture that is selected
    var selectedTexture: MTLTexture? {
        return layerManager.selectedTexture
    }

    var frameSize: CGSize = .zero {
        didSet {
            drawingBrush.frameSize = frameSize
            drawingEraser.frameSize = frameSize
        }
    }

    var brushDiameter: Int {
        get { (drawingBrush.tool as? DrawingToolBrush)!.diameter }
        set { (drawingBrush.tool as? DrawingToolBrush)?.diameter = newValue }
    }
    var eraserDiameter: Int {
        get { (drawingEraser.tool as? DrawingToolEraser)!.diameter }
        set { (drawingEraser.tool as? DrawingToolEraser)?.diameter = newValue }
    }

    var brushColor: UIColor {
        get { (drawingBrush.tool as? DrawingToolBrush)!.color }
        set { (drawingBrush.tool as? DrawingToolBrush)?.setValue(color: newValue) }
    }
    var eraserAlpha: Int {
        get { (drawingEraser.tool as? DrawingToolEraser)!.alpha }
        set { (drawingEraser.tool as? DrawingToolEraser)?.setValue(alpha: newValue)}
    }

    /// A protocol for managing drawing
    private (set) var drawing: Drawing?

    /// A protocol for managing transformations
    private var transforming: Transforming!

    /// A protocol for managing file input and output
    private var fileIO: FileIO!

    /// An instance for managing texture layers
    private (set) var layerManager = LayerManager()

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate
    
    var zipFileNameName: String {
        projectName + "." + CanvasViewModel.zipSuffix
    }

    static var zipSuffix: String {
        "zip"
    }
    static var thumbnailPath: String {
        "thumbnail.png"
    }
    static var jsonFileName: String {
        "data"
    }

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(fileIO: FileIO = FileIOImpl(),
         transforming: Transforming = TransformingImpl()) {
        self.fileIO = fileIO
        self.transforming = transforming

        $drawingTool
            .sink { [weak self] newValue in
                self?.setCurrentDrawing(newValue)
            }
            .store(in: &cancellables)
    }

    func initAllTextures(_ textureSize: CGSize) {
        layerManager.initLayerManager(textureSize)

        drawingBrush.initTextures(textureSize)
        drawingEraser.initTextures(textureSize)
    }
}

// MARK: Drawing
extension CanvasViewModel {
    func setCurrentDrawing(_ type: DrawingToolType) {
        switch type {
        case .brush:
            self.drawing = self.drawingBrush
        case .eraser:
            self.drawing = self.drawingEraser
        }
    }
    
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>,
                              matrix: CGAffineTransform,
                              touchState: TouchState,
                              _ commandBuffer: MTLCommandBuffer) {
        guard let selectedTexture else { return }
        
        drawing?.drawOnDrawingTexture(with: iterator,
                                      matrix: matrix,
                                      on: selectedTexture,
                                      touchState,
                                      commandBuffer)
        if touchState == .ended {
            updateThumbnail()
        }
    }
    func mergeAllLayers(backgroundColor: (Int, Int, Int),
                        to dstTexture: MTLTexture,
                        _ commandBuffer: MTLCommandBuffer) {
        guard let selectedTexture,
              let selectedTextures = drawing?.getDrawingTextures(selectedTexture) else { return }
        let selectedAlpha = layerManager.selectedLayerAlpha

        layerManager.mergeAllTextures(selectedTextures: selectedTextures.compactMap { $0 },
                                      selectedAlpha: selectedAlpha,
                                      backgroundColor: backgroundColor,
                                      to: dstTexture,
                                      commandBuffer)
    }

    private func updateThumbnail() {
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 1 * 1000 * 1000)
            if let selectedLayer = layerManager.selectedLayer {
                layerManager.updateThumbnail(selectedLayer)
            }
        }
    }
}

// MARK: Transforming
extension CanvasViewModel {
    func getMatrix(transformationData: TransformationData,
                   frameCenterPoint: CGPoint,
                   touchState: TouchState) -> CGAffineTransform? {
        transforming.getMatrix(transformationData: transformationData,
                               frameCenterPoint: frameCenterPoint,
                               touchState: touchState)
    }
    func setStoredMatrix(_ matrix: CGAffineTransform) {
        transforming.storedMatrix = matrix
    }
}

// MARK: IO
extension CanvasViewModel {
    func saveCanvasAsZipFile(rootTexture: MTLTexture,
                             thumbnailHeight: CGFloat = 512,
                             into folderURL: URL,
                             with zipFileName: String) throws {
        Task {
            let layers = try await LayerModel.convertToLayerModelCodableArray(layers: layerManager.layers,
                                                                              fileIO: fileIO,
                                                                              folderURL: folderURL)

            let thumbnail = rootTexture.uiImage?.resize(height: thumbnailHeight, scale: 1.0)
            try fileIO.saveImage(image: thumbnail,
                                 to: folderURL.appendingPathComponent(CanvasViewModel.thumbnailPath))

            let data = CanvasModelV2(textureSize: rootTexture.size,
                                     layerIndex: layerManager.index,
                                     layers: layers,
                                     thumbnailName: CanvasViewModel.thumbnailPath,
                                     drawingTool: drawingTool.rawValue,
                                     brushDiameter: (drawingBrush.tool as? DrawingToolBrush)!.diameter,
                                     eraserDiameter: (drawingEraser.tool as? DrawingToolEraser)!.diameter)

            try fileIO.saveJson(data,
                                to: folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))

            try fileIO.zip(folderURL,
                           to: URL.documents.appendingPathComponent(zipFileName))
        }
    }
    func loadCanvasDataV2(from zipFilePath: String, into folderURL: URL) throws -> CanvasModelV2? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))
    }
    func loadCanvasData(from zipFilePath: String, into folderURL: URL) throws -> CanvasModel? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))
    }

    func applyCanvasDataToCanvasV2(_ data: CanvasModelV2?, folderURL: URL, zipFilePath: String) throws {
        guard let layers = data?.layers,
              let layerIndex = data?.layerIndex,
              let textureSize = data?.textureSize,
              let rawValueDrawingTool = data?.drawingTool,
              let brushDiameter = data?.brushDiameter,
              let eraserDiameter = data?.eraserDiameter
        else {
            throw FileInputError.failedToApplyData
        }

        var newLayers: [LayerModel] = []

        try layers.forEach { layer in
            if let layer,
               let textureData = try Data(contentsOf: folderURL.appendingPathComponent(layer.textureName)).encodedHexadecimals {
                let newTexture = MTKTextureUtils.makeTexture(device, textureSize, textureData)
                let layerData = LayerModel.init(texture: newTexture,
                                                title: layer.title,
                                                isVisible: layer.isVisible,
                                                alpha: layer.alpha)
                newLayers.append(layerData)
            }
        }
        layerManager.layers = newLayers
        layerManager.index = layerIndex
        layerManager.selectedLayerAlpha = newLayers[layerIndex].alpha

        drawingTool = .init(rawValue: rawValueDrawingTool)
        (drawingBrush.tool as? DrawingToolBrush)!.diameter = brushDiameter
        (drawingEraser.tool as? DrawingToolEraser)!.diameter = eraserDiameter

        projectName = zipFilePath.fileName
    }
    func applyCanvasDataToCanvas(_ data: CanvasModel?, folderURL: URL, zipFilePath: String) throws {
        guard let textureName = data?.textureName,
              let textureSize = data?.textureSize,
              let rawValueDrawingTool = data?.drawingTool,
              let brushDiameter = data?.brushDiameter,
              let eraserDiameter = data?.eraserDiameter,
              let newTexture = try MTKTextureUtils.makeTexture(device,
                                                               url: folderURL.appendingPathComponent(textureName),
                                                               textureSize: textureSize) else {
            throw FileInputError.failedToApplyData
        }

        let layerData = LayerModel.init(texture: newTexture,
                                        title: "NewLayer")

        layerManager.layers.removeAll()
        layerManager.layers.append(layerData)
        layerManager.index = 0

        drawingTool = .init(rawValue: rawValueDrawingTool)
        (drawingBrush.tool as? DrawingToolBrush)!.diameter = brushDiameter
        (drawingEraser.tool as? DrawingToolEraser)!.diameter = eraserDiameter

        projectName = zipFilePath.fileName
    }

    var undoObject: UndoObject {
        return UndoObject(index: layerManager.index,
                          layers: layerManager.layers)
    }
}
