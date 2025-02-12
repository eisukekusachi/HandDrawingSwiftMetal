//
//  CanvasModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import MetalKit

struct CanvasModel {
    let projectName: String

    let textureSize: CGSize

    let layerIndex: Int
    let layers: [TextureLayer]

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        projectName: String,
        entity: CanvasEntity,
        folderURL: URL
    ) throws {
        self.layers = try TextureLayer.makeLayers(
            from: entity.layers,
            textureSize: entity.textureSize,
            folderURL: folderURL,
            device: device
        )
        self.layerIndex = entity.layerIndex

        self.projectName = projectName

        self.textureSize = entity.textureSize

        self.drawingTool = entity.drawingTool

        self.brushDiameter = entity.brushDiameter
        self.eraserDiameter = entity.eraserDiameter
    }

}

extension CanvasModel {

    static func getZipFileName(projectName: String) -> String {
        projectName + "." + URL.zipSuffix
    }

}
