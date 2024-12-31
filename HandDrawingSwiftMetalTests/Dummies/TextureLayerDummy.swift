//
//  TextureLayerDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import MetalKit
@testable import HandDrawingSwiftMetal

extension TextureLayer {

    static func generate(
        id: UUID = UUID(),
        texture: MTLTexture? = nil,
        title: String = "",
        thumbnail: UIImage? = nil,
        alpha: Int = 255,
        isVisible: Bool = true
    ) -> Self {
        .init(
            id: id,
            texture: texture,
            title: title,
            thumbnail: thumbnail,
            alpha: alpha,
            isVisible: isVisible
        )
    }

}
