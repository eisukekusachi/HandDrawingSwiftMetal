//
//  CanvasView+IO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension CanvasView {
    var zipFileNamePath: String {
        projectName + "." + CanvasView.zipSuffix
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
    func write(to folderUrl: URL) throws {
        guard let viewModel else { return }

        let textureName = UUID().uuidString
        let textureDataUrl = folderUrl.appendingPathComponent(textureName)

        // Thumbnail
        let imageURL = folderUrl.appendingPathComponent(CanvasView.thumbnailPath)
        try outputImage?.resize(height: 512, scale: 1.0)?.pngData()?.write(to: imageURL)

        // Texture
        autoreleasepool {
            try? Data(viewModel.layerManager.currentTexture.bytes).write(to: textureDataUrl)
        }

        // Data
        let codableData = CanvasModel(textureSize: textureSize,
                                      textureName: textureName,
                                      drawingTool: drawingTool.rawValue,
                                      brushDiameter: brushDiameter,
                                      eraserDiameter: eraserDiameter)

        if let jsonData = try? JSONEncoder().encode(codableData) {
            let jsonUrl = folderUrl.appendingPathComponent(CanvasView.jsonFilePath)
            try? String(data: jsonData, encoding: .utf8)?.write(to: jsonUrl, atomically: true, encoding: .utf8)
        }
    }
    func load(from model: CanvasModel, projectName: String, folderURL: URL) {
        guard let viewModel else { return }

        self.projectName = projectName

        if let textureName = model.textureName,
           let textureSize = model.textureSize {

            let textureUrl = folderURL.appendingPathComponent(textureName)
            let textureData: Data? = try? Data(contentsOf: textureUrl)

            if let texture = device?.makeTexture(textureSize, textureData?.encodedHexadecimals) {
                viewModel.layerManager.setTexture(texture)
            }
        }

        if let drawingTool = model.drawingTool {
            self.drawingTool = .init(rawValue: drawingTool)
        }

        if let diameter = model.brushDiameter {
            self.brushDiameter = diameter
        }
        if let diameter = model.eraserDiameter {
            self.eraserDiameter = diameter
        }
        
        clearUndo()

        refreshRootTexture()
        setNeedsDisplay()
    }
    
    func setTexture(textureSize: CGSize, folderUrl: URL, textureName: String) {

        let textureUrl = folderUrl.appendingPathComponent(textureName)
        let textureData: Data? = try? Data(contentsOf: textureUrl)

        if let texture = device?.makeTexture(textureSize, textureData?.encodedHexadecimals) {
            viewModel?.layerManager.setTexture(texture)
        }
    }
}
