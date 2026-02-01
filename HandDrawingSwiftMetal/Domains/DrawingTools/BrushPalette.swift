//
//  BrushPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import UIKit

final class BrushPalette: ObservableObject {

    private(set) var id: UUID

    @Published private(set) var colors: [UIColor] = []
    @Published private(set) var index: Int = 0

    public init(
        id: UUID = UUID(),
        colors: [UIColor] = [.black],
        index: Int = 0
    ) {
        self.id = id

        let newColors = colors.isEmpty ? [.black] : colors
        self.colors = newColors
        self.index = max(0, min(index, newColors.count - 1))
    }
}

extension BrushPalette {

    func setId(_ id: UUID) {
        self.id = id
    }

    var color: UIColor? {
        guard index < colors.count else { return nil }
        return colors[index]
    }

    func color(at index: Int) -> UIColor? {
        self.colors.indices.contains(index) ? colors[index] : nil
    }

    func select(_ index: Int) {
        self.index = index
    }

    func insert(_ color: UIColor, at index: Int) {
        guard (0 ... colors.count).contains(index) else { return }
        colors.insert(color, at: index)
    }

    func update(
        colors: [UIColor] = [],
        index: Int = 0
    ) {
        self.colors = colors.isEmpty ? [.black] : colors
        self.index = max(0, min(index, self.colors.count - 1))
    }

    func update(
        color: UIColor,
        at index: Int
    ) {
        guard colors.indices.contains(index) else { return }
        colors[index] = color
    }

    func remove(at index: Int) {
        guard colors.indices.contains(index) && colors.count > 1 else { return }
        colors.remove(at: index)
    }
}
