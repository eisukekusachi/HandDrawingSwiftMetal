//
//  LocalFileConvertible.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/12.
//

import Foundation

public protocol LocalFileConvertible: Sendable {
    associatedtype T: Codable & Sendable

    static var fileName: String { get }

    static func read(from url: URL) throws -> T

    /// Save this value to a local file at the specified URL
    func write(to url: URL) throws
}

public extension LocalFileConvertible where Self: Codable & Sendable, T == Self {
    func write(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }
}
