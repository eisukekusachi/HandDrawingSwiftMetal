//
//  CanvasDrawingToolType.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import Foundation

enum CanvasDrawingToolType: Int {
    case brush = 0
    case eraser = 1

    init(rawValue: Int) {
        switch rawValue {
        case 1:
            self = .eraser
        default:
            self = .brush
        }
    }
}
