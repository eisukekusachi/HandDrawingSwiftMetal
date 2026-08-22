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

    @Test("Confirms default color is set to .black when initialized with no colors")
    func testInitWithEmptyColors() async throws {
        let palette = BrushPalette(
            colors: [],
            selectedIndex: -1
        )

        #expect(palette.items.map(\.color) == [.black])
        #expect(palette.selectedIndex == 0)
    }

    @Test("Confirms selecting a color changes the current color")
    func testSelect() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            selectedIndex: 0
        )

        #expect(palette.selectedIndex == 0)
        #expect(palette.color == .black)

        palette.select(1)
        #expect(palette.selectedIndex == 1)
        #expect(palette.color == .red)
    }

    @Test("Confirms inserting a color at the specified index")
    func testInsert() async throws {
        let palette = BrushPalette(
            colors: [.black],
            selectedIndex: 0
        )

        palette.insert(.blue, at: 0)
        #expect(palette.items.map(\.color) == [.blue, .black])
    }

    @Test("Confirms it updates colors and selectedIndex")
    func testUpdateColorsAndIndex() async throws {
        let palette = BrushPalette(
            colors: [.black, .lightGray, .gray, .white],
            selectedIndex: 0
        )

        palette.update(colors: [.red, .green], selectedIndex: 1)

        #expect(palette.items.map(\.color) == [.red, .green])
        #expect(palette.selectedIndex == 1)
        #expect(palette.color == .green)
    }

    @Test("Confirms a color can be updated at the specified index")
    func testUpdateColorAtIndex() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            selectedIndex: 0
        )

        palette.update(color: .blue, at: 1)
        #expect(palette.items.map(\.color) == [.black, .blue])
    }

    @Test("Confirms removing a color at the specified index")
    func testRemove() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            selectedIndex: 0
        )

        palette.remove(at: 0)
        #expect(palette.items.map(\.color) == [.red])

        // Cannot remove when the palette has only one color
        palette.remove(at: 0)
        #expect(palette.items.count == 1)
        #expect(palette.items.map(\.color) == [.red])
    }
}
