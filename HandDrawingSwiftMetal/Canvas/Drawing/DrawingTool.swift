//
//  DrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import Foundation

enum DrawingTool: Int {
    case brush = 0
    case eraser = 1

    init?(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .brush
        case 1:
            self = .eraser
        default:
            return nil
        }
    }
}
