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
                             layerIndex: Int,
                             codableLayers: [LayerModelCodable],
                             tmpFolderURL: URL,
                             with zipFileName: String) throws {
        let thumbnail = rootTexture.uiImage?.resize(height: thumbnailHeight, scale: 1.0)
        try FileIOUtils.saveImage(image: thumbnail,
                                  to: tmpFolderURL.appendingPathComponent(URL.thumbnailPath))

        let data = CanvasModelV2(textureSize: rootTexture.size,
                                 layerIndex: layerIndex,
                                 layers: codableLayers,
                                 thumbnailName: URL.thumbnailPath,
                                 drawingTool: parameters.drawingToolSubject.value.rawValue,
                                 brushDiameter: parameters.brushDiameter,
                                 eraserDiameter: parameters.eraserDiameter)

        try fileIO.saveJson(data,
                            to: tmpFolderURL.appendingPathComponent(URL.jsonFileName))

        try fileIO.zip(tmpFolderURL,
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

        parameters.layerManager.layers = layers
        parameters.layerManager.index = layerIndex

        parameters.drawingToolSubject.send(.init(rawValue: rawValueDrawingTool))
        parameters.setBrushDiameter(brushDiameter)
        parameters.setEraserDiameter(eraserDiameter)

        projectName = zipFilePath.fileName
    }
    func applyCanvasDataToCanvas(_ data: CanvasModel?,
                                 folderURL: URL,
                                 zipFilePath: String) throws {
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

        parameters.layerManager.layers.removeAll()
        parameters.layerManager.layers.append(layerData)
        parameters.layerManager.index = 0

        parameters.drawingToolSubject.send(.init(rawValue: rawValueDrawingTool))
        parameters.setBrushDiameter(brushDiameter)
        parameters.setEraserDiameter(eraserDiameter)

        projectName = zipFilePath.fileName
    }
}
