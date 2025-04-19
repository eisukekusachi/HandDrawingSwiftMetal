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
    let layers: [TextureLayerEntity]

    let thumbnailName: String

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int

    init(
        thumbnailName: String,
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerEntity],
        canvasState: CanvasState
    ) {
        self.thumbnailName = thumbnailName

        self.textureSize = textureSize

        self.layerIndex = layerIndex
        self.layers = layers

        self.drawingTool = canvasState.drawingToolState.drawingToolType.rawValue
        self.brushDiameter = canvasState.drawingToolState.brush.diameter
        self.eraserDiameter = canvasState.drawingToolState.eraser.diameter
    }

    init(entity: OldCanvasEntity) {
        self.thumbnailName = entity.thumbnailName ?? ""

        self.textureSize = entity.textureSize ?? CGSize(width: 1, height: 1)

        self.layerIndex = 0
        self.layers = [.init(
            textureName: entity.textureName ?? "",
            title: "NewLayer",
            alpha: 255,
            isVisible: true)
        ]

        self.drawingTool = entity.drawingTool ?? 0
        self.brushDiameter = entity.brushDiameter ?? 8
        self.eraserDiameter = entity.eraserDiameter ?? 8
    }

}
