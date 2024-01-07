//
//  CanvasModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit

struct CanvasModelV2: Codable, Equatable {
    let textureSize: CGSize?
    let layerIndex: Int
    let layers: [LayerModelCodable?]?

    let thumbnailName: String?

    let drawingTool: Int?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}
struct CanvasModel: Codable {
    let textureSize: CGSize?
    let textureName: String?

    let thumbnailName: String?

    let drawingTool: Int?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}
