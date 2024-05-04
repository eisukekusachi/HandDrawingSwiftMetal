//
//  LayerEntityForExporting.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/03.
//

import MetalKit

struct LayerEntityForExporting: Codable, Equatable {
    let textureName: String
    let title: String
    let isVisible: Bool
    let alpha: Int
}

extension Array where Element == LayerEntityForExporting {

    func convertToLayerModel(
        device: MTLDevice,
        textureSize: CGSize,
        folderURL: URL
    ) throws -> [LayerEntity] {

        var layers: [LayerEntity] = []

        try self.forEach { layer in
            if  let textureData = try Data(contentsOf: folderURL.appendingPathComponent(layer.textureName)).encodedHexadecimals {
                let newTexture = MTKTextureUtils.makeTexture(device, textureSize, textureData)
                let layerData: LayerEntity = .init(
                    texture: newTexture,
                    title: layer.title,
                    isVisible: layer.isVisible,
                    alpha: layer.alpha
                )
                layers.append(layerData)
            }
        }

        if layers.count == 0 {
            layers.append(
                .init(
                    texture: MTKTextureUtils.makeTexture(device, textureSize),
                    title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
                )
            )
        }

        return layers
    }

}
