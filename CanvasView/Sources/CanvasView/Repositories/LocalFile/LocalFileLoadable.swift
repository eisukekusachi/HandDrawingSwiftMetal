//
//  LocalFileLoadable.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Foundation

public protocol LocalFileLoadable: Sendable {
    static func load(from url: URL) throws -> Self
}

public extension LocalFileLoadable where Self: Decodable {
    static func load(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
