//
//  CanvasError.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/03/07.
//

import Foundation

enum CanvasError: Error, LocalizedError {
    case textureSizeMismatch
    case failedToCreateCanvas

    public var errorDescription: String? {
        switch self {
        case .textureSizeMismatch:
            return "The texture size does not match the expected canvas size."
        case .failedToCreateCanvas:
            return "Failed to create the canvas."
        }
    }
}
