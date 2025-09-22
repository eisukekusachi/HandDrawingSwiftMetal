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

    @Test("Confirms it falls back to default values when no data is stored")
    func testInitWithDefaults() async throws {
        let tool = DrawingTool(
            initialBrushDiameter: 8,
            initialEraserDiameter: 8
        )

        #expect(tool.type == .brush)
        #expect(tool.brushDiameter == 8)
        #expect(tool.eraserDiameter == 8)
    }

    @Test("Confirms it can set the drawing tool type")
    func testSetDrawingTool() async throws {
        let tool = DrawingTool()
        #expect(tool.type == .brush)

        tool.setDrawingTool(.eraser)
        #expect(tool.type == .eraser)
    }

    @Test("Confirms it can set the brush diameter with Int")
    func testSetBrushDiameterInt() async throws {
        let tool = DrawingTool(
            initialBrushDiameter: 8
        )
        #expect(tool.brushDiameter == 8)

        tool.setBrushDiameter(25)
        #expect(tool.brushDiameter == 25)
    }

    @Test("Confirms it can set the eraser diameter with Int")
    func testSetEraserDiameterInt() async throws {
        let tool = DrawingTool(
            initialEraserDiameter: 8
        )
        #expect(tool.eraserDiameter == 8)

        tool.setEraserDiameter(30)
        #expect(tool.eraserDiameter == 30)
    }

    @Test("Confirms it can reset to default values")
    func testReset() async throws {
        let tool = DrawingTool(
            initialBrushDiameter: 8,
            initialEraserDiameter: 8
        )

        tool.setDrawingTool(.eraser)
        tool.setBrushDiameter(10)
        tool.setEraserDiameter(15)
        #expect(tool.type == .eraser)
        #expect(tool.brushDiameter == 10)
        #expect(tool.eraserDiameter == 15)

        tool.reset()

        #expect(tool.type == .brush)
        #expect(tool.brushDiameter == 8)
        #expect(tool.eraserDiameter == 8)
    }
}
