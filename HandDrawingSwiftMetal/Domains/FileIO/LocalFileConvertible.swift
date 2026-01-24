//
//  LocalFileConvertible.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/24.
//

import Foundation

public protocol LocalFileConvertible: Sendable, Codable {
    static var fileName: String { get }

    /// Read from a **directory** URL (fileName is appended)
    init(in directory: URL) throws

    /// Write to a **directory** URL (fileName is appended)
    func write(in directory: URL) throws
}

public extension LocalFileConvertible {
    init(in directory: URL) throws {
        let fileURL = directory.appendingPathComponent(Self.fileName)
        let data = try Data(contentsOf: fileURL)
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    func write(in directory: URL) throws {
        let fileURL = directory.appendingPathComponent(Self.fileName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: fileURL, options: .atomic)
    }
}
