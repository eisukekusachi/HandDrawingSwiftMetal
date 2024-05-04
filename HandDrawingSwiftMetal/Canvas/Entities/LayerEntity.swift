//
//  LayerEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit

struct LayerEntity: Identifiable, Equatable {

    let id: UUID
    var texture: MTLTexture?
    var title: String
    var thumbnail: UIImage?
    var isVisible: Bool
    var alpha: Int

    init(texture: MTLTexture?,
         title: String,
         isVisible: Bool = true,
         alpha: Int = 255) {
        self.id = UUID()
        self.texture = texture
        self.title = title
        self.isVisible = isVisible
        self.alpha = alpha
        
        updateThumbnail()
    }

}

extension LayerEntity {

    mutating func updateThumbnail() {
        thumbnail = texture?.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: LayerEntity, rhs: LayerEntity) -> Bool {
        lhs.id == rhs.id
    }

}

extension Array where Element == LayerEntityForExporting {
    func convertToLayerModel(device: MTLDevice, textureSize: CGSize, folderURL: URL) throws -> [LayerEntity] {
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
            layers.append(.init(
                texture: MTKTextureUtils.makeTexture(device, textureSize),
                title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
            ))
        }

        return layers
    }
}
