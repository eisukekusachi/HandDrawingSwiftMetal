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

    init(texture: MTLTexture?,
         title: String,
         isVisible: Bool = true) {
        self.id = UUID()
        self.texture = texture
        self.title = title
        self.isVisible = isVisible

        updateThumbnail()
    }

    mutating func updateThumbnail() {
        thumbnail = texture?.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: LayerModel, rhs: LayerModel) -> Bool {
        lhs.id == rhs.id
    }
}
