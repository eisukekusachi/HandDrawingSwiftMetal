//
//  DrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/24.
//

import UIKit

final class DrawingTool: ObservableObject {

    private(set) var id: UUID

    @Published var type: DrawingToolType = .brush
    @Published var brushDiameter: Int = 8
    @Published var eraserDiameter: Int = 8

    public init(
        id: UUID = UUID(),
        type: DrawingToolType = .brush,
        brushDiameter: Int = 8,
        eraserDiameter: Int = 8
    ) {
        self.id = id
        self.type = type
        self.brushDiameter = brushDiameter
        self.eraserDiameter = eraserDiameter
    }

    func setId(_ id: UUID) {
        self.id = id
    }

    func swapTool(_ type: DrawingToolType) {
        self.type = type == .brush ? .eraser: .brush
    }
}
