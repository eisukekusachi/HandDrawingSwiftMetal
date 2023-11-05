//
//  CanvasCodableData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import MetalKit

struct CanvasData {
    let texture: MTLTexture?

    let drawingTool: Int?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}

struct CanvasCodableData: Codable {
    let textureSize: CGSize?
    let textureName: String?

    let drawingTool: Int?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}
