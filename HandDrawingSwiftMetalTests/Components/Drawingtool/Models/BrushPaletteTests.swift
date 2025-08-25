//
//  BrushPaletteTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Testing
import UIKit
@testable import HandDrawingSwiftMetal

@MainActor
struct BrushPaletteTests {

    final class BrushPaletteStorageStub: BrushPaletteStorage {
        init(index: Int = 0, hexColors: [String] = []) {}
        func load() async throws -> (index: Int, hexColors: [String])? { nil }
        func save(index: Int, hexColors: [String]) async throws {}
    }

    @Test("Confirms it falls back to initial colors when no data is stored in CoreData")
    func testInitWithDefaults() async throws {
        let palette = BrushPalette(
            initialColors: [.black, .red],
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(palette.colors == [.black, .red])
        #expect(palette.currentIndex == 0)
    }

    @Test("Confirms selecting a color changes the current color")
    func testSelect() async throws {
        let palette = BrushPalette(
            initialColors: [.black, .red],
            initialIndex: 0,
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(palette.currentIndex == 0)
        #expect(palette.currentColor == .black)

        palette.select(1)
        #expect(palette.currentIndex == 1)
        #expect(palette.currentColor == .red)
    }

    @Test("Confirms inserting a color at the specified index")
    func testInsert() async throws {
        let palette = BrushPalette(
            initialColors: [.black],
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.insert(.blue, at: 0)
        #expect(palette.colors == [.blue, .black])
    }

    @Test("Confirms it updates colors and currentIndex")
    func testUpdateColorsAndIndex() async throws {
        let palette = BrushPalette(
            initialColors: [.black, .lightGray, .gray, .white],
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.update(colors: [.red, .green], currentIndex: 1)

        #expect(palette.colors == [.red, .green])
        #expect(palette.currentIndex == 1)
        #expect(palette.currentColor == .green)
    }

    @Test("Confirms a color can be updated at the specified index")
    func testUpdateColorAtIndex() async throws {
        let palette = BrushPalette(
            initialColors: [.black, .red],
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.update(.blue, at: 1)
        #expect(palette.colors == [.black, .blue])
    }

    @Test("Confirms removing a color at the specified index")
    func testRemove() async throws {
        let palette = BrushPalette(
            initialColors: [.black, .red],
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.remove(at: 0)
        #expect(palette.colors == [.red])

        // Cannot remove when the palette has only one color
        palette.remove(at: 0)
        #expect(palette.colors.count == 1)
        #expect(palette.colors == [.red])
    }

    @Test("Confirms it can reset with initial colors")
    func testReset() async throws {
        let palette = BrushPalette(
            initialColors: [.black, .red],
            storage: BrushPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.update(colors: [.red, .blue, .green], currentIndex: 2)
        #expect(palette.colors == [.red, .blue, .green])
        #expect(palette.currentIndex == 2)

        palette.reset()

        #expect(palette.colors == [.black, .red])
        #expect(palette.currentIndex == 0)
    }
}
