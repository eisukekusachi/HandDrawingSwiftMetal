//
//  LocalFileLoader.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/10/19.
//

import Foundation

public struct LocalFileLoader<T: LocalFileLoadable & Sendable>: Sendable {
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
        _ loader: LocalFileLoader<T>
    ) {
        self.fileName = loader.fileName
        self._load = loader.load(in:)
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
