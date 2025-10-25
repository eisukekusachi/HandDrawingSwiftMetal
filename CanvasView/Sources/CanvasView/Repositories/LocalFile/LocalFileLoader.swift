//
//  LocalFileLoader.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/10/19.
//

import Foundation

public struct LocalFileLoader<T: LocalFileLoadable & Sendable>: Sendable {

    private let onLoaded: @Sendable (T) -> Void

    public init(
        onLoaded: @escaping @Sendable (T) -> Void
    ) {
        self.onLoaded = onLoaded
    }

    public func load(fileURL: URL) throws {
        onLoaded(
            try T.load(from: fileURL)
        )
    }

    public func loadIgnoringError(fileURL: URL) {
       do {
           onLoaded(
               try T.load(from: fileURL)
           )
       } catch {
           Logger.error(error)
       }
   }
}
