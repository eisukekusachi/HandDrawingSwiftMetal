//
//  DrawingToolType.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/17.
//

import Foundation

enum DrawingToolType: Int {
    case brush = 0
    case eraser = 1

    init(rawValue: Int) {
        switch rawValue {
        case 1: self = .eraser
        default: self = .brush
        }
    }
}
