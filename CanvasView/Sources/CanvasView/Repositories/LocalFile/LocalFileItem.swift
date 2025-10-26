//
//  LocalFileItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/12.
//

import Foundation

public struct LocalFileItem<T: LocalFileConvertible & Sendable>: Sendable {
    let fileName: String
    let item: T

    public init(fileName: String, item: T) {
        self.fileName = fileName
        self.item = item
    }

    public func write(to url: URL) throws {
        try item.write(to: url.appendingPathComponent(fileName))
    }
}
