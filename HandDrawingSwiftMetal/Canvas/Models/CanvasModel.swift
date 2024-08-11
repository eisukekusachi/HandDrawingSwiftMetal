//
//  CanvasModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import MetalKit

final class CanvasModel {
    let projectName: String

    let textureSize: CGSize

    let layerIndex: Int
    let layers: [TextureLayer]

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int

    init(
        projectName: String,
        device: MTLDevice,
        entity: CanvasEntity,
        folderURL: URL
    ) {
        self.projectName = projectName

        self.textureSize = entity.textureSize

        self.layerIndex = entity.layerIndex
        self.layers = CanvasModel.makeLayers(
            from: entity.layers,
            device: device,
            textureSize: entity.textureSize,
            folderURL: folderURL
        )

        self.drawingTool = entity.drawingTool

        self.brushDiameter = entity.brushDiameter
        self.eraserDiameter = entity.eraserDiameter
    }

    static func makeLayers(
        from sourceLayers: [ImageLayerEntity],
        device: MTLDevice,
        textureSize: CGSize,
        folderURL: URL
    ) -> [TextureLayer] {

        var layers: [TextureLayer] = []

        try? sourceLayers.forEach { layer in

            let textureData = try Data(contentsOf: folderURL.appendingPathComponent(layer.textureName))

            if let hexadecimalData = textureData.encodedHexadecimals,
               let texture = MTKTextureUtils.makeTexture(device, textureSize, hexadecimalData) {
                layers.append(
                    .init(
                        texture: texture,
                        title: layer.title,
                        alpha: layer.alpha,
                        isVisible: layer.isVisible
                    )
                )
            }
        }

        if layers.count == 0,
           let newTexture = MTKTextureUtils.makeTexture(device, textureSize) {
            layers.append(
                .init(
                    texture: newTexture,
                    title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
                )
            )
        }

        return layers
    }

}

extension CanvasModel {

    static func getZipFileName(projectName: String) -> String {
        projectName + "." + URL.zipSuffix
    }

}
