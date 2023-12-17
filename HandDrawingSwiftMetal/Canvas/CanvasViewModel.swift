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
    var currentTexture: MTLTexture {
        return layerManager.currentTexture
    }

    /// An array containing a texture where a line is drawn and a texture that is selected
    var activeDrawingTextures: [MTLTexture?] {
        drawing?.getDrawingTextures(currentTexture) ?? []
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
    private var drawing: Drawing?

    /// A protocol for managing transformations
    private var transforming: Transforming!

    /// A protocol for managing texture layers
    private var layerManager: LayerManager!

    /// A protocol for managing file input and output
    private var fileIO: FileIO!

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

    /// A temporary folder URL used for file input and output
    static let tmpFolderURL = URL.documents.appendingPathComponent("tmpFolder")

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(fileIO: FileIO = FileIOImpl(),
         transforming: Transforming = TransformingImpl(),
         layerManager: LayerManager = LayerManagerImpl()) {
        self.fileIO = fileIO
        self.transforming = transforming
        self.layerManager = layerManager

        $drawingTool
            .sink { [weak self] newValue in
                self?.setCurrentDrawing(newValue)
            }
            .store(in: &cancellables)
    }

    func setFrameSize(_ size: CGSize) {
        drawingBrush.frameSize = size
        drawingEraser.frameSize = size
    }
    func initTextures(_ size: CGSize) {
        drawingBrush.initTextures(size)
        drawingEraser.initTextures(size)

        layerManager.initTextures(size)
    }
    func setCurrentTexture(_ texture: MTLTexture) {
        layerManager.setTexture(texture)
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
        drawing?.drawOnDrawingTexture(with: iterator,
                                      matrix: matrix,
                                      on: currentTexture,
                                      touchState,
                                      commandBuffer)
    }
    func mergeAllTextures(backgroundColor: (Int, Int, Int),
                          into dstTexture: MTLTexture,
                          _ commandBuffer: MTLCommandBuffer) {
        layerManager.merge(textures: activeDrawingTextures,
                           backgroundColor: backgroundColor,
                           into: dstTexture,
                           commandBuffer)
    }

    func clearDrawingTextures(_ commandBuffer: MTLCommandBuffer) {
        drawing?.clearDrawingTextures(commandBuffer)
    }
    func clearCurrentTexture(_ commandBuffer: MTLCommandBuffer) {
        layerManager.clearTexture(commandBuffer)
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
    func saveCanvasAsZipFile(texture: MTLTexture, 
                             textureName: String,
                             thumbnailHeight: CGFloat = 512,
                             into folderURL: URL,
                             with zipFileName: String) throws {
        let thumbnailName = CanvasViewModel.thumbnailPath
        let textureSize = texture.size

        try fileIO.saveImage(image: texture.uiImage?.resize(height: thumbnailHeight, scale: 1.0),
                             to: folderURL.appendingPathComponent(thumbnailName))

        try fileIO.saveImage(bytes: texture.bytes,
                             to: folderURL.appendingPathComponent(textureName))

        let data = CanvasModel(textureSize: textureSize,
                               textureName: textureName,
                               thumbnailName: thumbnailName,
                               drawingTool: drawingTool.rawValue,
                               brushDiameter: (drawingBrush.tool as? DrawingToolBrush)!.diameter,
                               eraserDiameter: (drawingEraser.tool as? DrawingToolEraser)!.diameter)

        try fileIO.saveJson(data,
                            to: folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))

        try fileIO.zip(folderURL,
                       to: URL.documents.appendingPathComponent(zipFileName))
    }
    func loadCanvasData(from zipFilePath: String, into folderURL: URL) throws -> CanvasModel? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))
    }
    func applyCanvasDataToCanvas(_ data: CanvasModel?, folderURL: URL, zipFilePath: String) throws {
        guard let textureName = data?.textureName,
              let textureSize = data?.textureSize,
              let drawingTool = data?.drawingTool,
              let brushDiameter = data?.brushDiameter,
              let eraserDiameter = data?.eraserDiameter,
              let newTexture = try? layerManager.makeTexture(fromDocumentsFolder: folderURL.appendingPathComponent(textureName),
                                                             textureSize: textureSize) else {
            throw FileInputError.failedToApplyData
        }

        self.drawingTool = .init(rawValue: drawingTool)
        (drawingBrush.tool as? DrawingToolBrush)!.diameter = brushDiameter
        (drawingEraser.tool as? DrawingToolEraser)!.diameter = eraserDiameter

        self.layerManager.setTexture(newTexture)

        self.projectName = zipFilePath.fileName
    }
}
