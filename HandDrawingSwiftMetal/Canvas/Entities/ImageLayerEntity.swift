//
//  ImageLayerEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/03.
//

import MetalKit

struct ImageLayerEntity: Codable, Equatable {
    /// The filename of the texture
    /// MTLTexture cannot be encoded into JSON,
    /// the texture is saved as a file, and this struct holds the `textureName` of the texture.
    let textureName: String
    /// The name of the layer
    let title: String
    /// The opacity of the layer
    let alpha: Int
    /// Whether the layer is visible or not
    let isVisible: Bool

}

extension Array where Element == ImageLayerEntity {

    func convertToImageLayerModel(
        device: MTLDevice,
        textureSize: CGSize,
        folderURL: URL
    ) throws -> [ImageLayerModel] {

        var layers: [ImageLayerModel] = []

        try self.forEach { layer in

            let textureData = try Data(contentsOf: folderURL.appendingPathComponent(layer.textureName))

            if let hexadecimalData = textureData.encodedHexadecimals,
               let newTexture = MTKTextureUtils.makeTexture(device, textureSize, hexadecimalData) {
                let layer: ImageLayerModel = .init(
                    texture: newTexture,
                    title: layer.title,
                    isVisible: layer.isVisible,
                    alpha: layer.alpha
                )
                layers.append(layer)
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
