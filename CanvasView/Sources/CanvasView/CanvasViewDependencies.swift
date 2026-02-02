//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {

    /// A class that manages drawing on the canvas
    let canvasRenderer: CanvasRenderer

    init(
        canvasRenderer: CanvasRenderer
    ) {
        self.canvasRenderer = canvasRenderer
    }
}
