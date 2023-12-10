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

    /// Manage texture layers
    private (set) var layerManager: LayerManagerProtocol = LayerManager()

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
    static var jsonFilePath: String {
        "data"
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
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

extension CanvasViewModel {
    func saveCanvas(outputImage: UIImage?, to zipFileName: String) throws {

        let folderUrl = URL.documents.appendingPathComponent("tmpFolder")
        let zipFileUrl = URL.documents.appendingPathComponent(zipFileName)

        // Clean up the temporary folder when done
        defer {
            try? FileManager.default.removeItem(atPath: folderUrl.path)
        }
        try FileManager.createNewDirectory(url: folderUrl)


        let textureSize = layerManager.currentTexture.size

        let textureName = UUID().uuidString
        let textureDataUrl = folderUrl.appendingPathComponent(textureName)

        // Thumbnail
        let imageURL = folderUrl.appendingPathComponent(CanvasViewModel.thumbnailPath)
        try outputImage?.resize(height: 512, scale: 1.0)?.pngData()?.write(to: imageURL)

        // Texture
        autoreleasepool {
            try? Data(layerManager.currentTexture.bytes).write(to: textureDataUrl)
        }

        // Data
        let codableData = CanvasModel(textureSize: textureSize,
                                      textureName: textureName,
                                      drawingTool: drawingTool.rawValue,
                                      brushDiameter: (drawingBrush.tool as? DrawingToolBrush)!.diameter,
                                      eraserDiameter: (drawingEraser.tool as? DrawingToolEraser)!.diameter)

        if let jsonData = try? JSONEncoder().encode(codableData) {
            let jsonUrl = folderUrl.appendingPathComponent(CanvasViewModel.jsonFilePath)
            try? String(data: jsonData, encoding: .utf8)?.write(to: jsonUrl, atomically: true, encoding: .utf8)
        }

        try FileOutput.zip(folderURL: folderUrl, zipFileURL: zipFileUrl)
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
