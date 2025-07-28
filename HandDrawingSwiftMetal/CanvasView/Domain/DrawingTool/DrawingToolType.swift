//
//  DrawingToolType.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/17.
//

import Foundation

public enum DrawingToolType: Int, Sendable {
    case brush = 0
    case eraser = 1

    public init(rawValue: Int) {
        switch rawValue {
        case 1: self = .eraser
        default: self = .brush
        }
    }
}
