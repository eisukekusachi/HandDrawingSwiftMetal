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
    final class DrawingToolStorageStub: DrawingToolStorageProtocol {
        func load() async throws -> (type: Int, brushDiameter: Int, eraserDiameter: Int)? { nil }
        func save(type: Int, brushDiameter: Int, eraserDiameter: Int) async throws {}
    }

    @Test("Confirms it falls back to default values when no data is stored")
    func testInitWithDefaults() async throws {
        let tool = DrawingTool(
            initialBrushDiameter: 8,
            initialEraserDiameter: 8,
            storage: DrawingToolStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(tool.type == .brush)
        #expect(tool.brushDiameter == 8)
        #expect(tool.eraserDiameter == 8)
    }

    @Test("Confirms it can update type and diameters")
    func testUpdate() async throws {
        let tool = DrawingTool(
            initialBrushDiameter: 8,
            initialEraserDiameter: 8,
            storage: DrawingToolStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        tool.update(type: .eraser, brushDiameter: 12, eraserDiameter: 20)

        #expect(tool.type == .eraser)
        #expect(tool.brushDiameter == 12)
        #expect(tool.eraserDiameter == 20)
    }

    @Test("Confirms it can reset to default values")
    func testReset() async throws {
        let tool = DrawingTool(
            initialBrushDiameter: 8,
            initialEraserDiameter: 8,
            storage: DrawingToolStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        tool.update(type: .eraser, brushDiameter: 10, eraserDiameter: 15)
        #expect(tool.type == .eraser)
        #expect(tool.brushDiameter == 10)
        #expect(tool.eraserDiameter == 15)

        tool.reset()

        #expect(tool.type == .brush)
        #expect(tool.brushDiameter == 8)
        #expect(tool.eraserDiameter == 8)
    }

    @Test("Confirms it can set the drawing tool type")
    func testSetDrawingTool() async throws {
        let tool = DrawingTool(
            storage: DrawingToolStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        tool.setDrawingTool(.eraser)
        #expect(tool.type == .eraser)
    }

    @Test("Confirms it can set the brush diameter with Int")
    func testSetBrushDiameterInt() async throws {
        let tool = DrawingTool(
            storage: DrawingToolStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        tool.setBrushDiameter(25)
        #expect(tool.brushDiameter == 25)
    }

    @Test("Confirms it can set the eraser diameter with Int")
    func testSetEraserDiameterInt() async throws {
        let tool = DrawingTool(
            storage: DrawingToolStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        tool.setEraserDiameter(30)
        #expect(tool.eraserDiameter == 30)
    }
}
