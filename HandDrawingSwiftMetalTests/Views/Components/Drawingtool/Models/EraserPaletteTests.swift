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

    typealias Subject = EraserPalette

    @Test
    func `Confirms default alpha is set to 255 when initialized with no alphas`() async throws {
        let subject: Subject = .init(
            alphas: [],
            selectedIndex: -1
        )

        #expect(subject.items.map(\.alpha) == [255])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms selecting an alpha changes the current alpha`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128],
            selectedIndex: 0
        )

        #expect(subject.selectedIndex == 0)
        #expect(subject.alpha == 64)

        subject.select(1)
        #expect(subject.selectedIndex == 1)
        #expect(subject.alpha == 128)
    }

    @Test
    func `Confirms inserting an alpha at the specified index`() async throws {
        let subject: Subject = .init(
            alphas: [128],
            selectedIndex: 0
        )

        subject.insert(64, at: 0)
        #expect(subject.items.map(\.alpha) == [64, 128])
    }

    @Test
    func `Confirms it updates alphas and selectedIndex`() async throws {
        let subject: Subject = .init(
            alphas: [255],
            selectedIndex: 0
        )

        subject.update(alphas: [32, 64, 128], selectedIndex: 2)

        #expect(subject.items.map(\.alpha) == [32, 64, 128])
        #expect(subject.selectedIndex == 2)
        #expect(subject.alpha == 128)
    }

    @Test
    func `Confirms an alpha can be updated at the specified index`() async throws {
        let subject: Subject = .init(
            alphas: [128, 255],
            selectedIndex: 0
        )

        subject.update(alpha: 64, at: 1)
        #expect(subject.items.map(\.alpha) == [128, 64])
    }

    @Test
    func `Confirms removing an alpha at the specified index`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128],
            selectedIndex: 0
        )

        subject.remove(at: 0)
        #expect(subject.items.map(\.alpha) == [128])
        #expect(subject.selectedIndex == 0)
        #expect(subject.alpha == 128)

        // Cannot remove when the palette has only one alpha
        subject.remove(at: 0)
        #expect(subject.items.count == 1)
        #expect(subject.items.map(\.alpha) == [128])
    }

    @Test
    func `Confirms selectedIndex moves when a preceding alpha is removed`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128, 255],
            selectedIndex: 2
        )

        subject.remove(at: 0)
        #expect(subject.items.map(\.alpha) == [128, 255])
        #expect(subject.selectedIndex == 1)
        #expect(subject.alpha == 255)
    }

    @Test
    func `Confirms selectedIndex is clamped when the last alpha is removed`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128],
            selectedIndex: 1
        )

        subject.remove(at: 1)
        #expect(subject.items.map(\.alpha) == [64])
        #expect(subject.selectedIndex == 0)
        #expect(subject.alpha == 64)
    }

    @Test
    func `Confirms removing an out-of-bounds index does nothing`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128],
            selectedIndex: 1
        )

        subject.remove(at: -1)
        subject.remove(at: 2)

        #expect(subject.items.map(\.alpha) == [64, 128])
        #expect(subject.selectedIndex == 1)
        #expect(subject.alpha == 128)
    }

    @Test
    func `Confirms selectedIndex stays when a following alpha is removed`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128, 255],
            selectedIndex: 0
        )

        subject.remove(at: 2)
        #expect(subject.items.map(\.alpha) == [64, 128])
        #expect(subject.selectedIndex == 0)
        #expect(subject.alpha == 64)
    }

    @Test
    func `Confirms selectedIndex stays on the next alpha when the selected alpha is removed`() async throws {
        let subject: Subject = .init(
            alphas: [64, 128, 255],
            selectedIndex: 1
        )

        subject.remove(at: 1)
        #expect(subject.items.map(\.alpha) == [64, 255])
        #expect(subject.selectedIndex == 1)
        #expect(subject.alpha == 255)
    }
}
