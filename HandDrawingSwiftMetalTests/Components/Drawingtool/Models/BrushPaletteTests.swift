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
            index: -1
        )

        #expect(palette.colors == [.black])
        #expect(palette.index == 0)
    }

    @Test("Confirms selecting a color changes the current color")
    func testSelect() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            index: 0
        )

        #expect(palette.index == 0)
        #expect(palette.color == .black)

        palette.select(1)
        #expect(palette.index == 1)
        #expect(palette.color == .red)
    }

    @Test("Confirms inserting a color at the specified index")
    func testInsert() async throws {
        let palette = BrushPalette(
            colors: [.black],
            index: 0
        )

        palette.insert(.blue, at: 0)
        #expect(palette.colors == [.blue, .black])
    }

    @Test("Confirms it updates colors and currentIndex")
    func testUpdateColorsAndIndex() async throws {
        let palette = BrushPalette(
            colors: [.black, .lightGray, .gray, .white],
            index: 0
        )

        palette.update(colors: [.red, .green], index: 1)

        #expect(palette.colors == [.red, .green])
        #expect(palette.index == 1)
        #expect(palette.color == .green)
    }

    @Test("Confirms a color can be updated at the specified index")
    func testUpdateColorAtIndex() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            index: 0
        )

        palette.update(color: .blue, at: 1)
        #expect(palette.colors == [.black, .blue])
    }

    @Test("Confirms removing a color at the specified index")
    func testRemove() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            index: 0
        )

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
            colors: [.black, .red],
            index: 0,
            initialColors: [.red]
        )

        palette.update(colors: [.red, .blue, .green], index: 2)
        #expect(palette.colors == [.red, .blue, .green])
        #expect(palette.index == 2)

        palette.reset()

        #expect(palette.colors == [.red])
        #expect(palette.index == 0)
    }
}
