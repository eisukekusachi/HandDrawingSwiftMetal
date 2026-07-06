//
//  IntRGB.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Foundation

struct IntRGBA: Equatable, Sendable {
    let r: Int
    let g: Int
    let b: Int
    let a: Int

    init(_ r: Int, _ g: Int, _ b: Int, _ a: Int) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}
