//
//  CanvasConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public enum StorageType: Sendable {
    case disk
    case memory
}

public struct CanvasConfiguration: Sendable {

    let projectName: String

    let textureSize: CGSize?

    let layerIndex: Int
    let layers: [TextureLayerModel]

    let drawingTool: DrawingToolType

    let brushColor: UIColor
    let brushDiameter: Int

    let eraserAlpha: Int
    let eraserDiameter: Int

    /// The background color of the canvas
    let backgroundColor: UIColor

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    let baseBackgroundColor: UIColor

    /// For the canvas’s textureLayerRepository type: if `.disk` is selected, Core Data is automatically created and textures are persisted
    let textureLayerRepository: StorageType

    /// For the repository type used to store undo textures. even if `.disk` is selected, it only uses disk storage temporarily and textures are not persisted.
    let undoTextureRepository: StorageType?

    public init(
        projectName: String = Calendar.currentDate,
        textureSize: CGSize? = nil,
        layerIndex: Int = 0,
        layers: [TextureLayerModel] = [],
        drawingTool: DrawingToolType = .brush,
        brushColor: UIColor = UIColor.black.withAlphaComponent(0.75),
        brushDiameter: Int = 8,
        eraserAlpha: Int = 155,
        eraserDiameter: Int = 44,
        backgroundColor: UIColor = .white,
        baseBackgroundColor: UIColor = UIColor(230, 230, 230),
        textureLayerRepository: StorageType = .disk,
        undoTextureRepository: StorageType? = .disk
    ) {
        self.projectName = projectName
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
        self.drawingTool = drawingTool
        self.brushColor = brushColor
        self.brushDiameter = brushDiameter
        self.eraserAlpha = eraserAlpha
        self.eraserDiameter = eraserDiameter
        self.backgroundColor = backgroundColor
        self.baseBackgroundColor = baseBackgroundColor
        self.textureLayerRepository = textureLayerRepository
        self.undoTextureRepository = undoTextureRepository
    }
}

extension CanvasConfiguration {

    public init(
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

        self.brushColor = UIColor.black.withAlphaComponent(0.75)
        self.eraserAlpha = 155

        self.textureLayerRepository = .disk
        self.undoTextureRepository = .disk
        self.backgroundColor = .white
        self.baseBackgroundColor = UIColor(230, 230, 230)
    }

    public init(
        entity: CanvasStorageEntity
    ) {
        self.projectName = entity.projectName ?? Calendar.currentDate

        self.textureSize = .init(
            width: CGFloat(entity.textureWidth),
            height: CGFloat(entity.textureHeight)
        )

        if let brush = entity.drawingTool?.brush,
           let colorHexString = brush.colorHex {
            self.brushColor = UIColor(hex: colorHexString)
            self.brushDiameter = Int(brush.diameter)
        } else {
            self.brushColor = UIColor.black.withAlphaComponent(0.75)
            self.brushDiameter = 8
        }

        if let eraser = entity.drawingTool?.eraser {
            self.eraserAlpha = Int(eraser.alpha)
            self.eraserDiameter = Int(eraser.diameter)
        } else {
            self.eraserAlpha = 155
            self.eraserDiameter = 44
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
        } else {
            self.layers = []
        }

        self.layerIndex = self.layers.firstIndex(where: { $0.id == entity.selectedLayerId }) ?? 0

        self.drawingTool = .brush

        self.backgroundColor = .white
        self.baseBackgroundColor = UIColor(230, 230, 230)
        self.textureLayerRepository = .disk
        self.undoTextureRepository = .disk
    }

    /// Returns an instance with the provided texture size if it was previously nil
    func resolvedTextureSize(_ textureSize: CGSize) -> Self {
        var newInstance = self
        if newInstance.textureSize == nil {
            //newInstance.textureSize = textureSize
            return .init(
                projectName: newInstance.projectName,
                textureSize: textureSize,
                layerIndex: newInstance.layerIndex,
                layers: newInstance.layers,
                drawingTool: newInstance.drawingTool,
                brushColor: newInstance.brushColor,
                brushDiameter: newInstance.brushDiameter,
                eraserAlpha: newInstance.eraserAlpha,
                eraserDiameter: newInstance.eraserDiameter,
                backgroundColor: newInstance.backgroundColor,
                baseBackgroundColor: newInstance.baseBackgroundColor,
                textureLayerRepository: newInstance.textureLayerRepository,
                undoTextureRepository: newInstance.undoTextureRepository
            )
        }
        return newInstance
    }
}
