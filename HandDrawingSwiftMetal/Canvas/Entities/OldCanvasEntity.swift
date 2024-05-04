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
