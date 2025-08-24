//
//  OldCanvasEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

struct OldCanvasEntity: Codable {
    let textureSize: CGSize?
    let textureName: String?

    let thumbnailName: String?

    let drawingTool: Int?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}

extension OldCanvasEntity: CanvasEntityConvertible {
    public func entity() -> CanvasEntity {
        CanvasEntity(
            textureSize: textureSize ?? .zero,
            layerIndex: 0,
            layers: [
                TextureLayerEntity(
                    textureName: textureName ?? "",
                    title: "NewLayer",
                    alpha: 255,
                    isVisible: true
                )
            ],
            thumbnailName: thumbnailName ?? ""
        )
    }
}
