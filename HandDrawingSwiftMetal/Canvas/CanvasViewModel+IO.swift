//
//  CanvasViewModel+IO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/04.
//

import MetalKit

extension CanvasViewModel {
    func saveCanvasAsZipFile(rootTexture: MTLTexture,
                             thumbnailHeight: CGFloat = 512,
                             codableLayers: [LayerModelCodable],
                             into folderURL: URL,
                             with zipFileName: String) throws {
        let thumbnail = rootTexture.uiImage?.resize(height: thumbnailHeight, scale: 1.0)
        try FileIOUtils.saveImage(image: thumbnail,
                                  to: folderURL.appendingPathComponent(URL.thumbnailPath))

        let data = CanvasModelV2(textureSize: rootTexture.size,
                                 layerIndex: layerManager.index,
                                 layers: codableLayers,
                                 thumbnailName: URL.thumbnailPath,
                                 drawingTool: drawingTool.rawValue,
                                 brushDiameter: (drawingBrush.tool as? DrawingToolBrush)!.diameter,
                                 eraserDiameter: (drawingEraser.tool as? DrawingToolEraser)!.diameter)

        try fileIO.saveJson(data,
                            to: folderURL.appendingPathComponent(URL.jsonFileName))

        try fileIO.zip(folderURL,
                       to: URL.documents.appendingPathComponent(zipFileName))
    }
    func loadCanvasDataV2(from zipFilePath: String, into folderURL: URL) throws -> CanvasModelV2? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(URL.jsonFileName))
    }
    func loadCanvasData(from zipFilePath: String, into folderURL: URL) throws -> CanvasModel? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(URL.jsonFileName))
    }

    func applyCanvasDataToCanvasV2(_ data: CanvasModelV2?,
                                   layers: [LayerModel],
                                   folderURL: URL,
                                   zipFilePath: String) throws {
        guard let layerIndex = data?.layerIndex,
              let rawValueDrawingTool = data?.drawingTool,
              let brushDiameter = data?.brushDiameter,
              let eraserDiameter = data?.eraserDiameter
        else {
            throw FileInputError.failedToApplyData
        }

        layerManager.layers = layers
        layerManager.index = layerIndex
        layerManager.selectedLayerAlpha = layers[layerIndex].alpha

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
}
