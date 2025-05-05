//
//  CanvasConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

struct CanvasConfiguration {

    var projectName: String = Calendar.currentDate()

    // If textureSize is nil, the size of the device’s drawable will be used instead
    var textureSize: CGSize?

    var layerIndex: Int = 0
    var layers: [TextureLayerModel] = []

    var drawingTool: DrawingToolType = .brush

    var brushColor: UIColor = UIColor.black.withAlphaComponent(0.75)
    var brushDiameter: Int = 8

    var eraserAlpha: Int = 155
    var eraserDiameter: Int = 44

}

extension CanvasConfiguration {

    init(
        projectName: String,
        entity: CanvasEntity
    ) {
        // Since the project name is the same as the folder name, it will not be managed in `CanvasEntity`
        self.projectName = projectName

        self.layerIndex = entity.layerIndex
        self.layers = entity.layers.map { .init(from: $0) }

        self.textureSize = entity.textureSize

        self.drawingTool = .init(rawValue: entity.drawingTool)

        self.brushDiameter = entity.brushDiameter
        self.eraserDiameter = entity.eraserDiameter
    }

    func getTextureSize(drawableSize: CGSize) -> CGSize {
        textureSize ?? drawableSize
    }

}

struct CanvasViewConfiguration {
    var canvasState: CanvasState
    var textureRepository: TextureRepository
}
