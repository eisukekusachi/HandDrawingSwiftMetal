//
//  EraserPaletteTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Testing
import UIKit
@testable import HandDrawingSwiftMetal

@MainActor
struct EraserPaletteTests {

    @Test("Confirms default alpha is set to 255 when initialized with no alphas")
    func testInitWithEmptyColors() async throws {
        let palette = EraserPalette(
            alphas: [],
            selectedIndex: -1
        )

        #expect(palette.alphas == [255])
        #expect(palette.selectedIndex == 0)
    }

    @Test("Confirms selecting an alpha changes the current alpha")
    func testSelect() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            selectedIndex: 0
        )

        #expect(palette.selectedIndex == 0)
        #expect(palette.alpha == 64)

        palette.select(1)
        #expect(palette.selectedIndex == 1)
        #expect(palette.alpha == 128)
    }

    @Test("Confirms inserting an alpha at the specified index")
    func testInsert() async throws {
        let palette = EraserPalette(
            alphas: [128],
            selectedIndex: 0
        )

        palette.insert(64, at: 0)
        #expect(palette.alphas == [64, 128])
    }

    @Test("Confirms it updates alphas and currentIndex")
    func testUpdateAlphasAndIndex() async throws {
        let palette = EraserPalette(
            alphas: [255],
            selectedIndex: 0
        )

        palette.update(alphas: [32, 64, 128], selectedIndex: 2)

        #expect(palette.alphas == [32, 64, 128])
        #expect(palette.selectedIndex == 2)
        #expect(palette.alpha == 128)
    }

    @Test("Confirms an alpha can be updated at the specified index")
    func testUpdateAlphaAtIndex() async throws {
        let palette = EraserPalette(
            alphas: [128, 255],
            selectedIndex: 0
        )

        palette.update(alpha: 64, at: 1)
        #expect(palette.alphas == [128, 64])
    }

    @Test("Confirms removing an alpha at the specified index")
    func testRemove() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            selectedIndex: 0
        )

        palette.remove(at: 0)
        #expect(palette.alphas == [128])

        // Cannot remove when the palette has only one alpha
        palette.remove(at: 0)
        #expect(palette.alphas.count == 1)
        #expect(palette.alphas == [128])
    }

    @Test("Confirms duplicating the selected alpha inserts a copy after it")
    func testDuplicateSelected() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            selectedIndex: 0
        )

        #expect(palette.canDuplicateSelected)
        palette.duplicateSelected()

        #expect(palette.alphas == [64, 64, 128])
        #expect(palette.selectedIndex == 0)
    }

    @Test("Confirms duplicating is ignored at the max alpha count")
    func testDuplicateSelectedAtMaxCount() async throws {
        let alphas = Array(repeating: 128, count: EraserPalette.maxAlphaCount)
        let palette = EraserPalette(
            alphas: alphas,
            selectedIndex: 0
        )

        #expect(!palette.canDuplicateSelected)
        palette.duplicateSelected()
        #expect(palette.alphas.count == EraserPalette.maxAlphaCount)

        palette.insert(64, at: 1)
        #expect(palette.alphas.count == EraserPalette.maxAlphaCount)
        #expect(palette.alphas == alphas)
    }

    @Test("Confirms removing the selected alpha")
    func testRemoveSelected() async throws {
        let palette = EraserPalette(
            alphas: [64, 128, 255],
            selectedIndex: 1
        )

        #expect(palette.canRemoveSelected)
        palette.removeSelected()

        #expect(palette.alphas == [64, 255])
        #expect(palette.selectedIndex == 1)
        #expect(palette.alpha == 255)
    }

    @Test("Confirms removing is ignored at the min alpha count")
    func testRemoveSelectedAtMinCount() async throws {
        let palette = EraserPalette(
            alphas: [128],
            selectedIndex: 0
        )

        #expect(!palette.canRemoveSelected)
        palette.removeSelected()
        #expect(palette.alphas == [128])
        #expect(palette.selectedIndex == 0)
    }

    @Test("Confirms reselecting the same alpha returns true")
    func testReselect() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            selectedIndex: 1
        )

        #expect(palette.select(1) == true)
        #expect(palette.select(0) == false)
    }
}
