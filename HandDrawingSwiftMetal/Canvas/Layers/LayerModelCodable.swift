//
//  LayerModelCodable.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/03.
//

import Foundation

struct LayerModelCodable: Codable {
    let textureName: String
    let title: String
    let isVisible: Bool
    let alpha: Int
}
