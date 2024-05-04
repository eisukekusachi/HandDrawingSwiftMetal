//
//  LayerEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit

struct LayerEntity: Identifiable, Equatable {

    let id: UUID
    var texture: MTLTexture
    var title: String
    var thumbnail: UIImage?
    var isVisible: Bool
    var alpha: Int

    init(texture: MTLTexture,
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
        thumbnail = texture.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: LayerEntity, rhs: LayerEntity) -> Bool {
        lhs.id == rhs.id
    }

}
