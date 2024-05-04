//
//  LayerEntityForExporting.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/03.
//

import MetalKit
/// LayerEntity for exporting.
/// Since MTLTexture cannot be encoded into JSON,
/// the texture is saved as a file, and this struct holds the filename of the texture.
struct LayerEntityForExporting: Codable, Equatable {
    /// The filename of the texture
    let textureName: String
    /// The name of the layer
    let title: String
    /// The opacity of the layer
    let alpha: Int
    /// Whether the layer is visible or not
    let isVisible: Bool
}

extension Array where Element == LayerEntityForExporting {

    func convertToLayerEntity(
        device: MTLDevice,
        textureSize: CGSize,
        folderURL: URL
    ) throws -> [LayerEntity] {

        var layers: [LayerEntity] = []

        try self.forEach { layer in
            if let textureData = try Data(contentsOf: folderURL.appendingPathComponent(layer.textureName)).encodedHexadecimals,
               let newTexture = MTKTextureUtils.makeTexture(device, textureSize, textureData) {

                let layerEntity: LayerEntity = .init(
                    texture: newTexture,
                    title: layer.title,
                    isVisible: layer.isVisible,
                    alpha: layer.alpha
                )
                layers.append(layerEntity)
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
