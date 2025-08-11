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

    public let brushColors: [IntRGBA]
    public let brushIndex: Int
    public let brushDiameter: Int

    public let eraserAlphas: [Int]
    public let eraserIndex: Int
    public let eraserDiameter: Int

    public init(
        projectName: String = Calendar.currentDate,
        textureSize: CGSize? = nil,
        layerIndex: Int = 0,
        layers: [TextureLayerItem] = [],
        drawingTool: DrawingToolType = .brush,
        brushColors: [IntRGBA] = [(0, 0, 0, 255)],
        brushIndex: Int = 0,
        brushDiameter: Int = 8,
        eraserAlphas: [Int] = [255],
        eraserIndex: Int = 0,
        eraserDiameter: Int = 44
    ) {
        self.projectName = projectName
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers

        self.drawingTool = drawingTool

        self.brushColors = brushColors
        self.brushIndex = brushIndex
        self.brushDiameter = brushDiameter

        self.eraserAlphas = eraserAlphas
        self.eraserIndex = eraserIndex
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

        self.textureSize = entity.textureSize

        self.layerIndex = entity.layerIndex
        self.layers = entity.layers.map {
            .init(textureName: $0.textureName, title: $0.title, alpha: $0.alpha, isVisible: $0.isVisible)
        }

        self.drawingTool = .init(rawValue: entity.drawingTool)

        self.brushColors = [UIColor.black.withAlphaComponent(0.75).rgba]
        self.brushIndex = 0
        self.brushDiameter = entity.brushDiameter

        self.eraserAlphas = [155]
        self.eraserIndex = 0
        self.eraserDiameter = entity.eraserDiameter
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
            self.brushColors = [UIColor(hex: colorHexString).rgba]
            self.brushIndex = 0
            self.brushDiameter = Int(brush.diameter)
        } else {
            self.brushColors = [UIColor.black.withAlphaComponent(0.75).rgba]
            self.brushIndex = 0
            self.brushDiameter = 8
        }

        if let eraser = entity.drawingTool?.eraser {
            self.eraserAlphas = [Int(eraser.alpha)]
            self.eraserIndex = 0
            self.eraserDiameter = Int(eraser.diameter)
        } else {
            self.eraserAlphas = [155]
            self.eraserIndex = 0
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

    public init(
        _ configuration: Self,
        newTextureSize: CGSize
    ) {
        self.textureSize = newTextureSize

        self.projectName = configuration.projectName

        self.layerIndex = configuration.layerIndex
        self.layers = configuration.layers

        self.drawingTool = configuration.drawingTool

        self.brushColors = configuration.brushColors
        self.brushIndex = configuration.brushIndex
        self.brushDiameter = configuration.brushDiameter

        self.eraserAlphas = configuration.eraserAlphas
        self.eraserIndex = configuration.eraserIndex
        self.eraserDiameter = configuration.eraserDiameter
    }

    public init(
        _ configuration: Self,
        newLayers: [TextureLayerItem]
    ) {
        self.projectName = configuration.projectName

        self.textureSize = configuration.textureSize

        self.layerIndex = configuration.layerIndex
        self.layers = newLayers

        self.drawingTool = configuration.drawingTool

        self.brushColors = configuration.brushColors
        self.brushIndex = configuration.brushIndex
        self.brushDiameter = configuration.brushDiameter

        self.eraserAlphas = configuration.eraserAlphas
        self.eraserIndex = configuration.eraserIndex
        self.eraserDiameter = configuration.eraserDiameter
    }
}
