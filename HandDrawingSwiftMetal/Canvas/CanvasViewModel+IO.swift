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
                             codableLayers: [LayerEntity],
                             tmpFolderURL: URL,
                             with zipFileName: String) throws {
        let thumbnail = rootTexture.uiImage?.resize(height: thumbnailHeight, scale: 1.0)
        try FileIOUtils.saveImage(image: thumbnail,
                                  to: tmpFolderURL.appendingPathComponent(URL.thumbnailPath))

        let data = CanvasEntity(textureSize: rootTexture.size,
                                layerIndex: layerIndex,
                                layers: codableLayers,
                                thumbnailName: URL.thumbnailPath,
                                drawingTool: drawingTool.drawingTool.rawValue,
                                brushDiameter: drawingTool.brushDiameter,
                                eraserDiameter: drawingTool.eraserDiameter)

        try fileIO.saveJson(data,
                            to: tmpFolderURL.appendingPathComponent(URL.jsonFileName))

        try fileIO.zip(tmpFolderURL,
                       to: URL.documents.appendingPathComponent(zipFileName))
    }
    func loadCanvasDataV2(from zipFilePath: String, into folderURL: URL) throws -> CanvasEntity? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(URL.jsonFileName))
    }
    func loadCanvasData(from zipFilePath: String, into folderURL: URL) throws -> OldCanvasEntity? {
        try fileIO.unzip(URL.documents.appendingPathComponent(zipFilePath),
                         to: folderURL)

        return try? fileIO.loadJson(folderURL.appendingPathComponent(URL.jsonFileName))
    }

    func applyCanvasDataToCanvasV2(_ data: CanvasEntity?,
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

        layerManager.initLayers(index: layerIndex, layers: layers)

        drawingTool.setBrushDiameter(brushDiameter)
        drawingTool.setEraserDiameter(eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: rawValueDrawingTool))

        projectName = zipFilePath.fileName
    }
    func applyCanvasDataToCanvas(_ data: OldCanvasEntity?,
                                 folderURL: URL,
                                 zipFilePath: String) throws {
        guard 
            let device: MTLDevice = MTLCreateSystemDefaultDevice(),
            let textureName = data?.textureName,
            let textureSize = data?.textureSize,
            let rawValueDrawingTool = data?.drawingTool,
            let brushDiameter = data?.brushDiameter,
            let eraserDiameter = data?.eraserDiameter,
            let newTexture = try MTKTextureUtils.makeTexture(
                device,
                url: folderURL.appendingPathComponent(textureName),
                textureSize: textureSize
            ) else {

            throw FileInputError.failedToApplyData
        }

        layerManager.initLayers(with: newTexture)

        drawingTool.setBrushDiameter(brushDiameter)
        drawingTool.setEraserDiameter(eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: rawValueDrawingTool))

        projectName = zipFilePath.fileName
    }
}
