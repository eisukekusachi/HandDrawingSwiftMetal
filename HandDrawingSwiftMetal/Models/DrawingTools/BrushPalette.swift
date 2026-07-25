//
//  BrushPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import PaletteEditView
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

final class BrushPalette: ObservableObject, ColorPaletteColorSource {

    private(set) var id: UUID

    var selectedColor: UIColor {
        color ?? .black
    }

    @Published private(set) var colors: [UIColor] = []
    @Published private(set) var selectedIndex: Int = 0

    public init(
        id: UUID = UUID(),
        colors: [UIColor] = initializeColors,
        selectedIndex: Int = 0
    ) {
        self.id = id

        let newColors = colors.isEmpty ? [.black] : colors
        self.colors = newColors
        self.selectedIndex = max(0, min(selectedIndex, newColors.count - 1))
    }
}

extension BrushPalette {

    func initializeData() {
        self.colors = initializeColors
        self.selectedIndex = 0
    }

    func setId(_ id: UUID) {
        self.id = id
    }

    var color: UIColor? {
        guard selectedIndex < colors.count else { return nil }
        return colors[selectedIndex]
    }

    func color(at index: Int) -> UIColor? {
        self.colors.indices.contains(index) ? colors[index] : nil
    }

    @discardableResult
    func select(_ index: Int) -> Bool {
        guard colors.indices.contains(index) else { return false }
        let didReselect = selectedIndex == index
        selectedIndex = index
        return didReselect
    }

    func insert(_ color: UIColor, at index: Int) {
        guard (0 ... colors.count).contains(index) else { return }
        var updated = colors
        updated.insert(color, at: index)
        colors = updated
    }

    func update(
        colors: [UIColor] = [],
        selectedIndex: Int = 0
    ) {
        self.colors = colors.isEmpty ? [.black] : colors
        self.selectedIndex = max(0, min(selectedIndex, self.colors.count - 1))
    }

    func update(
        color: UIColor,
        at index: Int
    ) {
        guard colors.indices.contains(index) else { return }
        var updated = colors
        updated[index] = color
        colors = updated
    }

    func remove(at index: Int) {
        guard colors.indices.contains(index) && colors.count > 1 else { return }
        var updated = colors
        updated.remove(at: index)
        colors = updated

        if selectedIndex > index {
            selectedIndex -= 1
        } else if selectedIndex >= updated.count {
            selectedIndex = updated.count - 1
        }
    }
}
