//
//  LocalFileNamedItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/12.
//

import Foundation

struct LocalFileNamedItem<T: LocalFileConvertible> {
    let name: String
    let item: T
}
