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

    private typealias Subject = BrushPalette

    @Test
    func `Confirms default color is set to .black when initialized with no colors`() {
        let subject = Subject(
            colors: [],
            selectedIndex: -1
        )

        #expect(subject.colors == [.black])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms selecting a color changes the current color`() {
        let subject = Subject(
            colors: [.black, .red],
            selectedIndex: 0
        )

        #expect(subject.selectedIndex == 0)
        #expect(subject.color == .black)

        subject.select(1)
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .red)
    }

    @Test
    func `Confirms inserting a color at the specified index`() {
        let subject = Subject(
            colors: [.black],
            selectedIndex: 0
        )

        subject.insert(.blue, at: 0)
        #expect(subject.colors == [.blue, .black])
    }

    @Test
    func `Confirms it updates colors and currentIndex`() {
        let subject = Subject(
            colors: [.black, .lightGray, .gray, .white],
            selectedIndex: 0
        )

        subject.update(colors: [.red, .green], selectedIndex: 1)

        #expect(subject.colors == [.red, .green])
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .green)
    }

    @Test
    func `Confirms a color can be updated at the specified index`() {
        let subject = Subject(
            colors: [.black, .red],
            selectedIndex: 0
        )

        subject.update(color: .blue, at: 1)
        #expect(subject.colors == [.black, .blue])
    }

    @Test
    func `Confirms removing a color at the specified index`() {
        let subject = Subject(
            colors: [.black, .red],
            selectedIndex: 0
        )

        subject.remove(at: 0)
        #expect(subject.colors == [.red])

        // Cannot remove when the palette has only one color
        subject.remove(at: 0)
        #expect(subject.colors.count == 1)
        #expect(subject.colors == [.red])
    }

    @Test
    func `Confirms duplicating the selected color inserts a copy after it`() {
        let subject = Subject(
            colors: [.black, .red],
            selectedIndex: 0
        )

        #expect(subject.canDuplicateSelected)
        subject.duplicateSelected()

        #expect(subject.colors == [.black, .black, .red])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms duplicating is ignored at the max color count`() {
        let colors = Array(repeating: UIColor.black, count: Subject.maxColorCount)
        let subject = Subject(
            colors: colors,
            selectedIndex: 0
        )

        #expect(!subject.canDuplicateSelected)
        subject.duplicateSelected()
        #expect(subject.colors.count == Subject.maxColorCount)

        subject.insert(.red, at: 1)
        #expect(subject.colors.count == Subject.maxColorCount)
        #expect(subject.colors == colors)
    }

    @Test
    func `Confirms removing the selected color`() {
        let subject = Subject(
            colors: [.black, .red, .blue],
            selectedIndex: 1
        )

        #expect(subject.canRemoveSelected)
        subject.removeSelected()

        #expect(subject.colors == [.black, .blue])
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .blue)
    }

    @Test
    func `Confirms removing is ignored at the min color count`() {
        let subject = Subject(
            colors: [.red],
            selectedIndex: 0
        )

        #expect(!subject.canRemoveSelected)
        subject.removeSelected()
        #expect(subject.colors == [.red])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms reselecting the same color returns true`() {
        let subject = Subject(
            colors: [.black, .red],
            selectedIndex: 1
        )

        #expect(subject.select(1) == true)
        #expect(subject.select(0) == false)
    }
}
