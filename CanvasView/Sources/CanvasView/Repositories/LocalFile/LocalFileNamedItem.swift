//
//  LocalFileNamedItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/12.
//

import Foundation

public struct LocalFileNamedItem<T: LocalFileConvertible & Sendable>: Sendable {
    let fileName: String
    let item: T

    public init(fileName: String, item: T) {
        self.fileName = fileName
        self.item = item
    }
}

public struct AnyLocalFileNamedItem: Sendable {
    public let fileName: String
    private let item: any LocalFileConvertible & Sendable

    public init<T: LocalFileConvertible & Sendable>(_ base: LocalFileNamedItem<T>) {
        self.fileName = base.fileName
        self.item = base.item
    }

    public init<T: LocalFileConvertible & Sendable>(fileName: String, item: T) {
        self.fileName = fileName
        self.item = item
    }

    public func write(to url: URL) throws {
        try item.write(to: url)
    }
}
