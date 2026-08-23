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

    typealias Subject = BrushPalette

    @Test
    func `Confirms default color is set to .black when initialized with no colors`() async throws {
        let subject: Subject = .init(
            colors: [],
            selectedIndex: -1
        )

        #expect(subject.items.map(\.color) == [.black])
        #expect(subject.selectedIndex == 0)
    }

    @Test
    func `Confirms selecting a color changes the current color`() async throws {
        let subject: Subject = .init(
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
    func `Confirms inserting a color at the specified index`() async throws {
        let subject: Subject = .init(
            colors: [.black],
            selectedIndex: 0
        )

        subject.insert(.blue, at: 0)
        #expect(subject.items.map(\.color) == [.blue, .black])
    }

    @Test
    func `Confirms it updates colors and selectedIndex`() async throws {
        let subject: Subject = .init(
            colors: [.black, .lightGray, .gray, .white],
            selectedIndex: 0
        )

        subject.update(colors: [.red, .green], selectedIndex: 1)

        #expect(subject.items.map(\.color) == [.red, .green])
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .green)
    }

    @Test
    func `Confirms a color can be updated at the specified index`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red],
            selectedIndex: 0
        )

        subject.update(color: .blue, at: 1)
        #expect(subject.items.map(\.color) == [.black, .blue])
    }

    @Test
    func `Confirms removing a color at the specified index`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red],
            selectedIndex: 0
        )

        subject.remove(at: 0)
        #expect(subject.items.map(\.color) == [.red])
        #expect(subject.selectedIndex == 0)
        #expect(subject.color == .red)

        // Cannot remove when the palette has only one color
        subject.remove(at: 0)
        #expect(subject.items.count == 1)
        #expect(subject.items.map(\.color) == [.red])
    }

    @Test
    func `Confirms selectedIndex moves when a preceding color is removed`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red, .blue],
            selectedIndex: 2
        )

        subject.remove(at: 0)
        #expect(subject.items.map(\.color) == [.red, .blue])
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .blue)
    }

    @Test
    func `Confirms selectedIndex is clamped when the last color is removed`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red],
            selectedIndex: 1
        )

        subject.remove(at: 1)
        #expect(subject.items.map(\.color) == [.black])
        #expect(subject.selectedIndex == 0)
        #expect(subject.color == .black)
    }

    @Test
    func `Confirms removing an out-of-bounds index does nothing`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red],
            selectedIndex: 1
        )

        subject.remove(at: -1)
        subject.remove(at: 2)

        #expect(subject.items.map(\.color) == [.black, .red])
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .red)
    }

    @Test
    func `Confirms selectedIndex stays when a following color is removed`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red, .blue],
            selectedIndex: 0
        )

        subject.remove(at: 2)
        #expect(subject.items.map(\.color) == [.black, .red])
        #expect(subject.selectedIndex == 0)
        #expect(subject.color == .black)
    }

    @Test
    func `Confirms selectedIndex stays on the next color when the selected color is removed`() async throws {
        let subject: Subject = .init(
            colors: [.black, .red, .blue],
            selectedIndex: 1
        )

        subject.remove(at: 1)
        #expect(subject.items.map(\.color) == [.black, .blue])
        #expect(subject.selectedIndex == 1)
        #expect(subject.color == .blue)
    }
}
