//
//  CanvasConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

enum StorageType {
    case disk
    case memory
}

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

    /// The background color of the canvas
    var backgroundColor: UIColor = .white

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    var baseBackgroundColor: UIColor = UIColor(230, 230, 230)

    /// For the canvas’s textureLayerRepository type: if `.disk` is selected, Core Data is automatically created and textures are persisted
    var textureLayerRepository: StorageType = .disk

    /// For the repository type used to store undo textures. even if `.disk` is selected, it only uses disk storage temporarily and textures are not persisted.
    var undoTextureRepository: StorageType? = .disk
}

extension CanvasConfiguration {

    init(
        projectName: String,
        entity: CanvasEntity
    ) {
        // Since the project name is the same as the folder name, it will not be managed in `CanvasEntity`
        self.projectName = projectName

        self.layerIndex = entity.layerIndex
        self.layers = entity.layers.map {
            .init(textureName: $0.textureName, title: $0.title, alpha: $0.alpha, isVisible: $0.isVisible)
        }

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

    /// Returns an instance with the provided texture size if it was previously nil
    func resolvedTextureSize(_ textureSize: CGSize) -> Self {
        var newInstance = self
        if newInstance.textureSize == nil {
            newInstance.textureSize = textureSize
        }
        return newInstance
    }

}
