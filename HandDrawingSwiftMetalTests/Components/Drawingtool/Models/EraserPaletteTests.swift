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

    final class EraserPaletteStorageStub: EraserPaletteStorage {
        init(index: Int = 0, alphas: [Int] = []) {}
        func load() async throws -> (index: Int, alphas: [Int])? { nil }
        func save(index: Int, alphas: [Int]) async throws {}
    }

    @Test("Confirms it falls back to initial alphas when no data is stored in CoreData")
    func testInitWithDefaults() async throws {
        let palette = EraserPalette(
            initialAlphas: [128, 255],
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(palette.alphas == [128, 255])
        #expect(palette.currentIndex == 0)
    }

    @Test("Confirms selecting an alpha changes the current alpha")
    func testSelect() async throws {
        let palette = EraserPalette(
            initialAlphas: [64, 128],
            initialIndex: 0,
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(palette.currentIndex == 0)
        #expect(palette.currentAlpha == 64)

        palette.select(1)
        #expect(palette.currentIndex == 1)
        #expect(palette.currentAlpha == 128)
    }

    @Test("Confirms inserting an alpha at the specified index")
    func testInsert() async throws {
        let palette = EraserPalette(
            initialAlphas: [128],
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.insert(64, at: 0)
        #expect(palette.alphas == [64, 128])
    }

    @Test("Confirms it updates alphas and currentIndex")
    func testUpdateAlphasAndIndex() async throws {
        let palette = EraserPalette(
            initialAlphas: [255],
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.update(alphas: [32, 64, 128], currentIndex: 2)

        #expect(palette.alphas == [32, 64, 128])
        #expect(palette.currentIndex == 2)
        #expect(palette.currentAlpha == 128)
    }

    @Test("Confirms an alpha can be updated at the specified index")
    func testUpdateAlphaAtIndex() async throws {
        let palette = EraserPalette(
            initialAlphas: [128, 255],
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.update(64, at: 1)
        #expect(palette.alphas == [128, 64])
    }

    @Test("Confirms removing an alpha at the specified index")
    func testRemove() async throws {
        let palette = EraserPalette(
            initialAlphas: [64, 128],
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.remove(at: 0)
        #expect(palette.alphas == [128])

        // Cannot remove when the palette has only one alpha
        palette.remove(at: 0)
        #expect(palette.alphas.count == 1)
        #expect(palette.alphas == [128])
    }

    @Test("Confirms it can reset with initial alphas")
    func testReset() async throws {
        let palette = EraserPalette(
            initialAlphas: [64, 128],
            storage: EraserPaletteStorageStub()
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        palette.update(alphas: [32, 64, 96], currentIndex: 1)
        #expect(palette.alphas == [32, 64, 96])
        #expect(palette.currentIndex == 1)

        palette.reset()

        #expect(palette.alphas == [64, 128])
        #expect(palette.currentIndex == 0)
    }
}
