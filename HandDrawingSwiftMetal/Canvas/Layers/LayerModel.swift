//
//  LayerModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit

struct LayerModel: Identifiable, Equatable {
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

    mutating func updateThumbnail() {
        thumbnail = texture?.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: LayerModel, rhs: LayerModel) -> Bool {
        lhs.id == rhs.id
    }
}

extension Array where Element == LayerEntity {
    func convertToLayerModel(device: MTLDevice, textureSize: CGSize, folderURL: URL) throws -> [LayerModel] {
        var layers: [LayerModel] = []

        try self.forEach { layer in
            if  let textureData = try Data(contentsOf: folderURL.appendingPathComponent(layer.textureName)).encodedHexadecimals {
                let newTexture = MTKTextureUtils.makeTexture(device, textureSize, textureData)
                let layerData = LayerModel.init(texture: newTexture,
                                                title: layer.title,
                                                isVisible: layer.isVisible,
                                                alpha: layer.alpha)
                layers.append(layerData)
            }
        }

        if layers.count == 0 {
            layers.append(LayerModel.init(texture: MTKTextureUtils.makeTexture(device, textureSize),
                                          title: TimeStampFormatter.current(template: "MMM dd HH mm ss")))
        }

        return layers
    }
}
