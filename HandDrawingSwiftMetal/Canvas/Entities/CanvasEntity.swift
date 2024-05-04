//
//  CanvasEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

struct CanvasEntity: Codable, Equatable {
    let textureSize: CGSize
    let layerIndex: Int
    let layers: [LayerEntityForExporting]

    let thumbnailName: String

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int

    init(
        thumbnailName: String,
        textureSize: CGSize,
        layerIndex: Int,
        layers: [LayerEntityForExporting],
        drawingTool: DrawingToolModel
    ) {
        self.thumbnailName = thumbnailName

        self.textureSize = textureSize

        self.layerIndex = layerIndex
        self.layers = layers

        self.drawingTool = drawingTool.drawingTool.rawValue
        self.brushDiameter = drawingTool.brushDiameter
        self.eraserDiameter = drawingTool.eraserDiameter
    }

    init(entity: OldCanvasEntity) {
        self.thumbnailName = entity.thumbnailName ?? ""

        self.textureSize = entity.textureSize ?? CGSize(width: 1, height: 1)

        self.layerIndex = 0
        self.layers = [.init(
            textureName: entity.textureName ?? "",
            title: "NewLayer",
            isVisible: true,
            alpha: 255)
        ]

        self.drawingTool = entity.drawingTool ?? 0
        self.brushDiameter = entity.brushDiameter ?? 8
        self.eraserDiameter = entity.eraserDiameter ?? 8
    }

}
