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
            index: -1
        )

        #expect(palette.alphas == [255])
        #expect(palette.index == 0)
    }

    @Test("Confirms selecting an alpha changes the current alpha")
    func testSelect() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            index: 0
        )

        #expect(palette.index == 0)
        #expect(palette.alpha == 64)

        palette.select(1)
        #expect(palette.index == 1)
        #expect(palette.alpha == 128)
    }

    @Test("Confirms inserting an alpha at the specified index")
    func testInsert() async throws {
        let palette = EraserPalette(
            alphas: [128],
            index: 0
        )

        palette.insert(64, at: 0)
        #expect(palette.alphas == [64, 128])
    }

    @Test("Confirms it updates alphas and currentIndex")
    func testUpdateAlphasAndIndex() async throws {
        let palette = EraserPalette(
            alphas: [255],
            index: 0
        )

        palette.update(alphas: [32, 64, 128], index: 2)

        #expect(palette.alphas == [32, 64, 128])
        #expect(palette.index == 2)
        #expect(palette.alpha == 128)
    }

    @Test("Confirms an alpha can be updated at the specified index")
    func testUpdateAlphaAtIndex() async throws {
        let palette = EraserPalette(
            alphas: [128, 255],
            index: 0
        )

        palette.update(alpha: 64, at: 1)
        #expect(palette.alphas == [128, 64])
    }

    @Test("Confirms removing an alpha at the specified index")
    func testRemove() async throws {
        let palette = EraserPalette(
            alphas: [64, 128],
            index: 0
        )

        palette.remove(at: 0)
        #expect(palette.alphas == [128])

        // Cannot remove when the palette has only one alpha
        palette.remove(at: 0)
        #expect(palette.alphas.count == 1)
        #expect(palette.alphas == [128])
    }
}
