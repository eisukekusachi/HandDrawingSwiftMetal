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

        #expect(palette.items.map(\.alpha) == [255])
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
        #expect(palette.items.map(\.alpha) == [64, 128])
    }

    @Test("Confirms it updates alphas and selectedIndex")
    func testUpdateAlphasAndIndex() async throws {
        let palette = EraserPalette(
            alphas: [255],
            selectedIndex: 0
        )

        palette.update(alphas: [32, 64, 128], selectedIndex: 2)

        #expect(palette.items.map(\.alpha) == [32, 64, 128])
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
        #expect(palette.items.map(\.alpha) == [128, 64])
    }

    @Test("Confirms removing an alpha at the specified index")
    func testRemove() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            selectedIndex: 0
        )

        palette.remove(at: 0)
        #expect(palette.items.map(\.alpha) == [128])

        // Cannot remove when the palette has only one alpha
        palette.remove(at: 0)
        #expect(palette.items.count == 1)
        #expect(palette.items.map(\.alpha) == [128])
    }
}
