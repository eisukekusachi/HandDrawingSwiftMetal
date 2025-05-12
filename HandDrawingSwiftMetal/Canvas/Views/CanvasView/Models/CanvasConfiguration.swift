//
//  CanvasConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

struct CanvasConfiguration {

    var projectName: String = Calendar.currentDate

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

    init(
        entity: CanvasStorageEntity
    ) {
        self.projectName = entity.projectName ?? ""

        self.textureSize = .init(
            width: CGFloat(entity.textureWidth),
            height: CGFloat(entity.textureHeight)
        )

        if let brush = entity.drawingTool?.brush,
           let colorHexString = brush.colorHex {
            self.brushColor = UIColor(hex: colorHexString)
            self.brushDiameter = Int(brush.diameter)
        }

        if let eraser = entity.drawingTool?.eraser {
            self.eraserAlpha = Int(eraser.alpha)
            self.eraserDiameter = Int(eraser.diameter)
        }

        if let layers = entity.textureLayers as? Set<TextureLayerStorageEntity> {
            self.layers = layers
                .sorted { $0.orderIndex < $1.orderIndex }
                .enumerated()
                .map { index, layer in
                    TextureLayerModel(
                        id: TextureLayerModel.id(from: layer.fileName),
                        title: layer.title ?? "",
                        alpha: Int(layer.alpha),
                        isVisible: layer.isVisible
                    )
                }
        }

        self.layerIndex = self.layers.firstIndex(where: { $0.id == entity.selectedLayerId }) ?? 0
    }

    func createConfigurationWithValidTextureSize(_ newTextureSize: CGSize) -> Self {
        var configuration = self
        if configuration.textureSize?.width ?? .zero < MTLRenderer.minimumTextureSize.width ||
            configuration.textureSize?.height ?? .zero < MTLRenderer.minimumTextureSize.height
        {
            configuration.textureSize = newTextureSize
        }
        return configuration
    }

}

struct CanvasViewControllerConfiguration {
    var canvasState: CanvasState
    var textureRepository: TextureRepository
}
