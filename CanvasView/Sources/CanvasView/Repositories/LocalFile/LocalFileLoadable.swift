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

public struct LocalFileNamedLoader<T: LocalFileLoadable & Sendable>: Sendable {
    public let fileName: String
    private let onLoaded: @Sendable (T) -> Void

    public init(
        fileName: String,
        onLoaded: @escaping @Sendable (T) -> Void
    ) {
        self.fileName = fileName
        self.onLoaded = onLoaded
    }

    @Sendable func load(in directory: URL) throws {
        let url = directory.appendingPathComponent(fileName)
        let value = try T.load(from: url)
        onLoaded(value)
    }
}

public struct AnyLocalFileLoader: Sendable {
    public let fileName: String
    private let _load: @Sendable (URL) throws -> Void

    public init<T: LocalFileLoadable & Sendable>(
        _ base: LocalFileNamedLoader<T>
    ) {
        self.fileName = base.fileName
        self._load = base.load(in:)
    }

    public func load(in directory: URL) throws {
        try _load(directory)
    }

    public func loadIgnoringError(in directory: URL) {
       do {
           try _load(directory)
       } catch {
           Logger.error(error)
       }
   }
}
