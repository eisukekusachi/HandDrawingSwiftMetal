//
//  CanvasModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit

struct CanvasModel: Codable {
    let textureSize: CGSize?
    let textureName: String?

    let thumbnailName: String?

    let drawingTool: Int?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}
