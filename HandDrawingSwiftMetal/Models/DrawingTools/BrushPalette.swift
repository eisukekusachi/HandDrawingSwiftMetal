//
//  BrushPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import PaletteView
import UIKit

fileprivate let initializeColors: [UIColor] = [
    .black.withAlphaComponent(0.8),
    .gray.withAlphaComponent(0.8),
    .red.withAlphaComponent(0.8),
    .blue.withAlphaComponent(0.8),
    .green.withAlphaComponent(0.8),
    .yellow.withAlphaComponent(0.8),
    .purple.withAlphaComponent(0.8)
]

final class BrushPalette: ObservableObject, ColorPaletteDisplayProtocol {

    private(set) var id: UUID

    @Published private(set) var items: [ColorPaletteItem] = []
    @Published private(set) var selectedIndex: Int = 0

    public init(
        id: UUID = UUID(),
        colors: [UIColor] = initializeColors,
        selectedIndex: Int = 0
    ) {
        self.id = id

        let newColors = colors.isEmpty ? [.black] : colors
        self.items = Self.makeItems(from: newColors)
        self.selectedIndex = max(0, min(selectedIndex, newColors.count - 1))
    }
}

extension BrushPalette {

    func initializeData() {
        items = Self.makeItems(from: initializeColors)
        selectedIndex = 0
    }

    func setId(_ id: UUID) {
        self.id = id
    }

    var color: UIColor? {
        guard selectedIndex < items.count else { return nil }
        return items[selectedIndex].color
    }

    func color(at index: Int) -> UIColor? {
        items.indices.contains(index) ? items[index].color : nil
    }

    @discardableResult
    func select(_ index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        let didReselect = selectedIndex == index
        selectedIndex = index
        return didReselect
    }

    func insert(_ color: UIColor, at index: Int) {
        guard (0 ... items.count).contains(index) else { return }
        items.insert(ColorPaletteItem(color: color), at: index)
    }

    func update(
        colors: [UIColor] = [],
        selectedIndex: Int = 0
    ) {
        let newColors = colors.isEmpty ? [.black] : colors
        items = Self.makeItems(from: newColors)
        self.selectedIndex = max(0, min(selectedIndex, newColors.count - 1))
    }

    func update(
        color: UIColor,
        at index: Int
    ) {
        guard items.indices.contains(index) else { return }
        items[index] = ColorPaletteItem(id: items[index].id, color: color)
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) && items.count > 1 else { return }
        items.remove(at: index)

        if selectedIndex > index {
            selectedIndex -= 1
        } else if selectedIndex >= items.count {
            selectedIndex = items.count - 1
        }
    }
}

private extension BrushPalette {
    static func makeItems(from colors: [UIColor]) -> [ColorPaletteItem] {
        colors.map { ColorPaletteItem(color: $0) }
    }
}
