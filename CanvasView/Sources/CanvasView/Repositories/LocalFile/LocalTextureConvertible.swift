//
//  LocalTextureConvertible.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/10/26.
//

import MetalKit

public protocol LocalTextureConvertible: Sendable {
    /// Save this value to a local file at the specified URL
    func write(to url: URL, device: MTLDevice?) async throws
}
