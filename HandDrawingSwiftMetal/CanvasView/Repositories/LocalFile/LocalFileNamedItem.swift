//
//  LocalFileNamedItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/12.
//

import Foundation

public struct LocalFileNamedItem<T: LocalFileConvertible & Sendable>: Sendable {
    let name: String
    let item: T
}
