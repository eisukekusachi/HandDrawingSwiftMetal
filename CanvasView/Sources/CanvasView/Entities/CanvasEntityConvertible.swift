//
//  File.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/24.
//

import Foundation

public protocol CanvasEntityConvertible: Decodable {
    func entity() -> CanvasEntity
}
