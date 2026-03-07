//
//  CanvasError.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/03/07.
//

import Foundation

public enum CanvasError: Error, LocalizedError {
    case textureSizeMismatch

    public var errorDescription: String? {
        switch self {
        case .textureSizeMismatch:
            return "The texture size does not match the expected canvas size."
        }
    }
}
