//
//  CanvasEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

struct CanvasEntity: Codable, Equatable {
    let textureSize: CGSize
    let layerIndex: Int
    let layers: [LayerEntity]

    let thumbnailName: String

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int
}
