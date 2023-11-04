//
//  Canvas+IO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension Canvas {
    var fileNamePath: String {
        projectName + "." + zipSuffix
    }
    private var zipSuffix: String {
        "zip"
    }
    private var thumbnailPath: String {
        "thumbnail.png"
    }
    private var fileDataPath: String {
        "data"
    }
    func write(to folderUrl: URL) throws {

        let textureName = UUID().uuidString
        let textureDataUrl = folderUrl.appendingPathComponent(textureName)

        // Texture
        autoreleasepool {
            try? Data(layers.currentTexture.bytes).write(to: textureDataUrl)
        }

        // Thumbnail
        let imageURL = folderUrl.appendingPathComponent(thumbnailPath)
        try outputImage?.resize(height: 512, scale: 1.0)?.pngData()?.write(to: imageURL)

        // Data
        let codableData = CanvasCodableData(textureName: textureName,
                                            brushDiameter: brushDiameter,
                                            eraserDiameter: eraserDiameter)

        if let jsonData = try? JSONEncoder().encode(codableData) {
            let jsonUrl = folderUrl.appendingPathComponent(fileDataPath)
            try? String(data: jsonData, encoding: .utf8)?.write(to: jsonUrl, atomically: true, encoding: .utf8)
        }
    }
}
