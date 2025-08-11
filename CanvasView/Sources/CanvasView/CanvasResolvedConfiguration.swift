//
//  CanvasResolvedConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

public struct CanvasResolvedConfiguration {

    public let projectName: String

    public let textureSize: CGSize

    public let layerIndex: Int
    public let layers: [TextureLayerModel]

    public let drawingTool: DrawingToolType

    // TODO: Remove brush-related code
    public let brushColors: [IntRGBA]
    public let brushIndex: Int
    public let brushDiameter: Int

    // TODO: Remove eraser-related code
    public let eraserAlphas: [Int]
    public let eraserIndex: Int
    public let eraserDiameter: Int

    public init(
        projectName: String,
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerModel],
        drawingTool: DrawingToolType,
        brushColors: [IntRGBA],
        brushIndex: Int,
        brushDiameter: Int,
        eraserAlphas: [Int],
        eraserIndex: Int,
        eraserDiameter: Int
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

public extension CanvasResolvedConfiguration {

    init(
        configuration: CanvasConfiguration,
        defaultTextureSize: CGSize
    ) async throws {
        projectName = configuration.projectName

        textureSize = configuration.textureSize ?? defaultTextureSize

        layerIndex = configuration.layerIndex
        layers = configuration.layers.map {
            .init(item: $0, thumbnail: nil)
        }

        drawingTool = configuration.drawingTool

        brushColors = configuration.brushColors
        brushIndex = configuration.brushIndex
        brushDiameter = configuration.brushDiameter

        eraserAlphas = configuration.eraserAlphas
        eraserIndex = configuration.eraserIndex
        eraserDiameter = configuration.eraserDiameter
    }

    var selectedLayerId: UUID {
        layers[layerIndex].id
    }

    var brushColor: UIColor {
        UIColor.init(rgba: brushColors[brushIndex])
    }

    var eraserAlpha: Int {
        eraserAlphas[eraserIndex]
    }
}
