//
//  ViewSizeTests.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2026/07/05.
//

import CoreGraphics
import Testing

@testable import CanvasView

@MainActor
struct ViewSizeTests {

    typealias Subject = ViewSize

    private let touchLocation: CGPoint = .init(x: 200, y: 400)
    private let frameSize: CGSize = .init(width: 400, height: 800)

    @Test
    func `convertScreenLocationToTextureLocation maps frame center to texture center when sizes match`() {
        let result = Subject.convertScreenLocationToTextureLocation(
            touchLocation: touchLocation,
            frameSize: frameSize,
            drawableSize: .init(width: 800, height: 800),
            textureSize: .init(width: 800, height: 800)
        )

        #expect(result == CGPoint(x: 400, y: 400))
    }

    @Test
    func `convertScreenLocationToTextureLocation maps frame center to texture center when sizes differ`() {
        let result = Subject.convertScreenLocationToTextureLocation(
            touchLocation: touchLocation,
            frameSize: frameSize,
            drawableSize: .init(width: 800, height: 800),
            textureSize: .init(width: 1600, height: 1600)
        )

        #expect(result == CGPoint(x: 800, y: 800))
    }
}
