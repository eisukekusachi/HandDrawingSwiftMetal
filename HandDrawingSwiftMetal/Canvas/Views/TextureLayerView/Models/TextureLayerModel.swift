//
//  TextureLayerModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

struct TextureLayerModel: Identifiable, Equatable {
    /// The unique identifier for the layer
    var id: UUID = UUID()
    /// The name of the layer
    var title: String = ""
    /// The opacity of the layer
    var alpha: Int = 255
    /// Whether the layer is visible or not
    var isVisible: Bool = true

}

extension TextureLayerModel {

    init(
        from textureLayerEntity: TextureLayerEntity
    ) {
        self.init(
            id: TextureLayerEntity.id(from: textureLayerEntity),
            title: textureLayerEntity.title,
            alpha: textureLayerEntity.alpha,
            isVisible: textureLayerEntity.isVisible
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Uses the ID as the filename
    var fileName: String {
        id.uuidString
    }

}
