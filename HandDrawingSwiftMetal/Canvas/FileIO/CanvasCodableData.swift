//
//  CanvasCodableData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import Foundation

struct CanvasCodableData: Codable {
    let textureName: String?

    let brushDiameter: Int?
    let eraserDiameter: Int?
}
