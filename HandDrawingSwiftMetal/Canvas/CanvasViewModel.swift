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

    /// Manage drawing
    private (set) var drawing: DrawingProtocol?

    /// Drawing with a brush
    var drawingBrush = DrawingBrush()

    /// Drawing with an eraser
    var drawingEraser = DrawingEraser()

    /// Manage transformations
    var transforming: TransformingProtocol = Transforming()

    var currentTexture: MTLTexture {
        return layerManager.currentTexture
    }
    var textures: [MTLTexture?] {
        drawing?.getDrawingTextures(currentTexture) ?? []
    }

    private var fileIO: FileIO!
    private var jsonIO: JsonIO!

    /// Manage texture layers
    private (set) var layerManager: LayerManager!

    /// The name of the file to be saved
    var projectName: String = Calendar.currentDate
    
    var zipFileNamePath: String {
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

    static let folderURL = URL.documents.appendingPathComponent("tmpFolder")

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(fileIO: FileIO = FileIOImpl(),
         jsonIO: JsonIO = JsonIOImpl(),
         layerManager: LayerManager = LayerManagerImpl()) {
        self.fileIO = fileIO
        self.jsonIO = jsonIO
        self.layerManager = layerManager
        
        $drawingTool
            .sink { [weak self] newValue in
                self?.setCurrentDrawing(newValue)
            }
            .store(in: &cancellables)

        drawingTool = .brush
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
                              _ touchState: TouchState,
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
        layerManager.merge(textures: textures,
                           backgroundColor: backgroundColor,
                           into: dstTexture,
                           commandBuffer)
    }

    func clearCurrentTexture(_ commandBuffer: MTLCommandBuffer) {
        layerManager.clearTexture(commandBuffer)
    }
}

// MARK: IO
extension CanvasViewModel {
    func saveCanvasAsZipFile(texture: MTLTexture, 
                             textureName: String,
                             thumbnailHeight: CGFloat = 512, 
                             folderURL: URL,
                             zipFileName: String) throws {
        let thumbnailName = CanvasViewModel.thumbnailPath
        let textureSize = texture.size

        try fileIO.saveImage(image: texture.uiImage?.resize(height: thumbnailHeight, scale: 1.0),
                             url: folderURL.appendingPathComponent(thumbnailName))

        try fileIO.saveImage(bytes: texture.bytes,
                             url: folderURL.appendingPathComponent(textureName))

        let data = CanvasModel(textureSize: textureSize,
                               textureName: textureName,
                               thumbnailName: thumbnailName,
                               drawingTool: drawingTool.rawValue,
                               brushDiameter: (drawingBrush.tool as? DrawingToolBrush)!.diameter,
                               eraserDiameter: (drawingEraser.tool as? DrawingToolEraser)!.diameter)

        try jsonIO.saveJson(data,
                            to: folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))

        try fileIO.zip(folderURL,
                       to: URL.documents.appendingPathComponent(zipFileName))
    }
    func loadCanvas(folderURL: URL, zipFilePath: String) throws -> CanvasModel? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? jsonIO.loadJson(folderURL.appendingPathComponent(CanvasViewModel.jsonFileName))
    }
    func applyDataToCanvas(_ data: CanvasModel?, folderURL: URL, zipFilePath: String) throws {
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

// Transforming
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
