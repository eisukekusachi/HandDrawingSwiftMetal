//
//  BrushPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import Combine
import UIKit

@MainActor
protocol BrushPaletteProtocol {

    var color: UIColor? { get }

    func color(at index: Int) -> UIColor?

    func select(_ index: Int)

    func insert(_ color: UIColor, at index: Int)

    func update(colors: [UIColor], index: Int)

    func update(color: UIColor, at index: Int)

    func remove(at index: Int)

    func reset()
}

@MainActor
public final class BrushPalette: BrushPaletteProtocol, ObservableObject {

    @Published private(set) var colors: [UIColor] = []
    @Published private(set) var index: Int = 0

    private let initialColors: [UIColor]

    public init(
        colors: [UIColor],
        index: Int = 0,
        initialColors: [UIColor]? = nil
    ) {
        let newColors = colors.isEmpty ? [.black] : colors
        self.colors = newColors
        self.index = max(0, min(index, newColors.count - 1))
        self.initialColors = initialColors ?? newColors
    }
}

extension BrushPalette {

    public var color: UIColor? {
        guard index < colors.count else { return nil }
        return colors[index]
    }

    public func color(at index: Int) -> UIColor? {
        self.colors.indices.contains(index) ? colors[index] : nil
    }

    public func select(_ index: Int) {
        self.index = index
    }

    public func insert(_ color: UIColor, at index: Int) {
        guard (0 ... colors.count).contains(index) else { return }
        colors.insert(color, at: index)
    }

    public func update(
        colors: [UIColor] = [],
        index: Int = 0
    ) {
        self.colors = colors.isEmpty ? [.black] : colors
        self.index = max(0, min(index, self.colors.count - 1))
    }

    public func update(
        color: UIColor,
        at index: Int
    ) {
        guard colors.indices.contains(index) else { return }
        colors[index] = color
    }

    public func remove(at index: Int) {
        guard colors.indices.contains(index) && colors.count > 1 else { return }
        colors.remove(at: index)
    }

    public func reset() {
        colors = initialColors
        index = 0
    }
}
