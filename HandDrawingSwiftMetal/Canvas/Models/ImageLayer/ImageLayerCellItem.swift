//
//  ImageLayerCellItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit

struct ImageLayerCellItem: ImageLayer {
    /// The unique identifier for the layer
    let id: UUID
    /// The texture of the layer
    var texture: MTLTexture
    /// The name of the layer
    var title: String
    /// The thumbnail image of the layer
    var thumbnail: UIImage?
    /// The opacity of the layer
    var alpha: Int
    /// Whether the layer is visible or not
    var isVisible: Bool

}

extension ImageLayerCellItem {

    init(
        texture: MTLTexture,
        title: String,
        isVisible: Bool = true,
        alpha: Int = 255
    ) {
        self.id = UUID()
        self.texture = texture
        self.title = title
        self.isVisible = isVisible
        self.alpha = alpha
        
        updateThumbnail()
    }

    mutating func updateThumbnail() {
        thumbnail = texture.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: ImageLayerCellItem, rhs: ImageLayerCellItem) -> Bool {
        lhs.id == rhs.id
    }

}
