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

        #expect(palette.colors == [.black])
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
        #expect(palette.colors == [.blue, .black])
    }

    @Test("Confirms it updates colors and currentIndex")
    func testUpdateColorsAndIndex() async throws {
        let palette = BrushPalette(
            colors: [.black, .lightGray, .gray, .white],
            selectedIndex: 0
        )

        palette.update(colors: [.red, .green], selectedIndex: 1)

        #expect(palette.colors == [.red, .green])
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
        #expect(palette.colors == [.black, .blue])
    }

    @Test("Confirms removing a color at the specified index")
    func testRemove() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            selectedIndex: 0
        )

        palette.remove(at: 0)
        #expect(palette.colors == [.red])

        // Cannot remove when the palette has only one color
        palette.remove(at: 0)
        #expect(palette.colors.count == 1)
        #expect(palette.colors == [.red])
    }

    @Test("Confirms duplicating the selected color inserts a copy after it")
    func testDuplicateSelected() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            selectedIndex: 0
        )

        #expect(palette.canDuplicateSelected)
        palette.duplicateSelected()

        #expect(palette.colors == [.black, .black, .red])
        #expect(palette.selectedIndex == 0)
    }

    @Test("Confirms duplicating is ignored at the max color count")
    func testDuplicateSelectedAtMaxCount() async throws {
        let colors = Array(repeating: UIColor.black, count: BrushPalette.maxColorCount)
        let palette = BrushPalette(
            colors: colors,
            selectedIndex: 0
        )

        #expect(!palette.canDuplicateSelected)
        palette.duplicateSelected()
        #expect(palette.colors.count == BrushPalette.maxColorCount)

        palette.insert(.red, at: 1)
        #expect(palette.colors.count == BrushPalette.maxColorCount)
        #expect(palette.colors == colors)
    }

    @Test("Confirms removing the selected color")
    func testRemoveSelected() async throws {
        let palette = BrushPalette(
            colors: [.black, .red, .blue],
            selectedIndex: 1
        )

        #expect(palette.canRemoveSelected)
        palette.removeSelected()

        #expect(palette.colors == [.black, .blue])
        #expect(palette.selectedIndex == 1)
        #expect(palette.color == .blue)
    }

    @Test("Confirms removing is ignored at the min color count")
    func testRemoveSelectedAtMinCount() async throws {
        let palette = BrushPalette(
            colors: [.red],
            selectedIndex: 0
        )

        #expect(!palette.canRemoveSelected)
        palette.removeSelected()
        #expect(palette.colors == [.red])
        #expect(palette.selectedIndex == 0)
    }

    @Test("Confirms reselecting the same color returns true")
    func testReselect() async throws {
        let palette = BrushPalette(
            colors: [.black, .red],
            selectedIndex: 1
        )

        #expect(palette.select(1) == true)
        #expect(palette.select(0) == false)
    }
}
