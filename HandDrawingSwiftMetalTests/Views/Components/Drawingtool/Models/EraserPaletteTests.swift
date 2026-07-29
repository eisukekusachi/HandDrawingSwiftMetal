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

    private typealias Subject = EraserPalette

    @Test
    func `Confirms default alpha is set to 255 when initialized with no alphas`() {
        let subject = Subject(
            alphas: [],
            selectedIndex: -1
        )

        #expect(subject.alphas == [255])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms selecting an alpha changes the current alpha`() {
        let subject = Subject(
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
    func `Confirms inserting an alpha at the specified index`() {
        let subject = Subject(
            alphas: [128],
            selectedIndex: 0
        )

        subject.insert(64, at: 0)
        #expect(subject.alphas == [64, 128])
    }

    @Test
    func `Confirms it updates alphas and currentIndex`() {
        let subject = Subject(
            alphas: [255],
            selectedIndex: 0
        )

        subject.update(alphas: [32, 64, 128], selectedIndex: 2)

        #expect(subject.alphas == [32, 64, 128])
        #expect(subject.selectedIndex == 2)
        #expect(subject.alpha == 128)
    }

    @Test
    func `Confirms an alpha can be updated at the specified index`() {
        let subject = Subject(
            alphas: [128, 255],
            selectedIndex: 0
        )

        subject.update(alpha: 64, at: 1)
        #expect(subject.alphas == [128, 64])
    }

    @Test
    func `Confirms removing an alpha at the specified index`() {
        let subject = Subject(
            alphas: [64, 128],
            selectedIndex: 0
        )

        subject.remove(at: 0)
        #expect(subject.alphas == [128])

        // Cannot remove when the palette has only one alpha
        subject.remove(at: 0)
        #expect(subject.alphas.count == 1)
        #expect(subject.alphas == [128])
    }

    @Test
    func `Confirms duplicating the selected alpha inserts a copy after it`() {
        let subject = Subject(
            alphas: [64, 128],
            selectedIndex: 0
        )

        #expect(subject.canDuplicateSelected)
        subject.duplicateSelected()

        #expect(subject.alphas == [64, 64, 128])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms duplicating is ignored at the max alpha count`() {
        let alphas = Array(repeating: 128, count: Subject.maxAlphaCount)
        let subject = Subject(
            alphas: alphas,
            selectedIndex: 0
        )

        #expect(!subject.canDuplicateSelected)
        subject.duplicateSelected()
        #expect(subject.alphas.count == Subject.maxAlphaCount)

        subject.insert(64, at: 1)
        #expect(subject.alphas.count == Subject.maxAlphaCount)
        #expect(subject.alphas == alphas)
    }

    @Test
    func `Confirms removing the selected alpha`() {
        let subject = Subject(
            alphas: [64, 128, 255],
            selectedIndex: 1
        )

        #expect(subject.canRemoveSelected)
        subject.removeSelected()

        #expect(subject.alphas == [64, 255])
        #expect(subject.selectedIndex == 1)
        #expect(subject.alpha == 255)
    }

    @Test
    func `Confirms removing is ignored at the min alpha count`() {
        let subject = Subject(
            alphas: [128],
            selectedIndex: 0
        )

        #expect(!subject.canRemoveSelected)
        subject.removeSelected()
        #expect(subject.alphas == [128])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms reselecting the same alpha returns true`() {
        let subject = Subject(
            alphas: [64, 128],
            selectedIndex: 1
        )

        #expect(subject.select(1) == true)
        #expect(subject.select(0) == false)
    }
}
