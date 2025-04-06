//
//  CanvasModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import Foundation

struct CanvasModel {

    var projectName: String = Calendar.currentDate

    var textureSize: CGSize?

    var layerIndex: Int = 0
    var layers: [TextureLayerModel] = []

    var drawingTool: Int = 0

    var brushDiameter: Int = 8
    var eraserDiameter: Int = 8

}

extension CanvasModel {

    init(
        projectName: String,
        entity: CanvasEntity
    ) {
        // Since the project name is the same as the folder name, it will not be managed in `CanvasEntity`
        self.projectName = projectName

        self.layerIndex = entity.layerIndex
        self.layers = entity.layers.map { .init(from: $0) }

        self.textureSize = entity.textureSize

        self.drawingTool = entity.drawingTool

        self.brushDiameter = entity.brushDiameter
        self.eraserDiameter = entity.eraserDiameter
    }

    func getTextureSize(drawableTextureSize: CGSize) -> CGSize {
        textureSize ?? drawableTextureSize
    }

}
