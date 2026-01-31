//
//  DrawingToolTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Testing
import UIKit
@testable import HandDrawingSwiftMetal

@MainActor
struct DrawingToolTests {

    typealias Subject = DrawingTool

    @Test
    func `The drawing tool is switched`() {
        let tool = DrawingTool()
        #expect(tool.type == .brush)

        tool.swapTool(.brush)

        #expect(tool.type == .eraser)

        tool.swapTool(.eraser)

        #expect(tool.type == .brush)
    }
}
