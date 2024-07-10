//
//  CanvasModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import MetalKit

final class CanvasModel {
    let projectName: String

    let textureSize: CGSize

    let layerIndex: Int
    let layers: [ImageLayerModel]

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int

    init(
        projectName: String,
        device: MTLDevice,
        entity: CanvasEntity,
        folderURL: URL
    ) {
        self.projectName = projectName

        self.textureSize = entity.textureSize

        self.layerIndex = entity.layerIndex
        self.layers = try! entity.layers.convertToImageLayerModel(
            device: device,
            textureSize: entity.textureSize,
            folderURL: folderURL
        )

        self.drawingTool = entity.drawingTool

        self.brushDiameter = entity.brushDiameter
        self.eraserDiameter = entity.eraserDiameter
    }

}
