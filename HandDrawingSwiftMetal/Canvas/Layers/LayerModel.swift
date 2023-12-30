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

    init(texture: MTLTexture?) {
        self.id = UUID()
        self.texture = texture
    }

    static func == (lhs: LayerModel, rhs: LayerModel) -> Bool {
        lhs.id == rhs.id
    }
}
