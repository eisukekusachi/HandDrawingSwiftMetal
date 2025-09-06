//
//  IntRGB.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Foundation

public struct IntRGB: Codable, Equatable, Sendable {
    public let r: Int
    public let g: Int
    public let b: Int

    public init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }

    public var tuple: (Int, Int, Int) {
        (r, g, b)
    }
}

public struct IntRGBA: Codable, Equatable, Sendable {
    public let r: Int
    public let g: Int
    public let b: Int
    public let a: Int

    public init(_ r: Int, _ g: Int, _ b: Int, _ a: Int) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public var tuple: (Int, Int, Int, Int) {
        (r, g, b, a)
    }
}
