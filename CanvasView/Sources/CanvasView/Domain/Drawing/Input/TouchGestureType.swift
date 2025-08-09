//
//  TouchGestureType.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

public enum TouchGestureType: Int, Sendable {
    /// The status is still undetermined
    case undetermined

    case drawing

    case transforming
}
