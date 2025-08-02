//
//  CanvasConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public struct CanvasConfiguration: Sendable {

    public let projectName: String

    public let textureSize: CGSize?

    public let layerIndex: Int
    public let layers: [TextureLayerItem]

    public let drawingTool: DrawingToolType

    public let brushColor: UIColor
    public let brushDiameter: Int

    public let eraserAlpha: Int
    public let eraserDiameter: Int

    public init(
        projectName: String = Calendar.currentDate,
        textureSize: CGSize? = nil,
        layerIndex: Int = 0,
        layers: [TextureLayerItem] = [],
        drawingTool: DrawingToolType = .brush,
        brushColor: UIColor = UIColor.black.withAlphaComponent(0.75),
        brushDiameter: Int = 8,
        eraserAlpha: Int = 155,
        eraserDiameter: Int = 44
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
                    TextureLayerItem(
                        id: TextureLayerItem.id(from: layer.fileName),
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
    }

    /// Returns an instance with the provided texture size if it was previously nil
    func resolvedTextureSize(_ textureSize: CGSize) -> Self {
        if self.textureSize == nil {
            return .init(
                projectName: projectName,
                textureSize: textureSize,
                layerIndex: layerIndex,
                layers: layers,
                drawingTool: drawingTool,
                brushColor: brushColor,
                brushDiameter: brushDiameter,
                eraserAlpha: eraserAlpha,
                eraserDiameter: eraserDiameter
            )
        }
        return self
    }
}
