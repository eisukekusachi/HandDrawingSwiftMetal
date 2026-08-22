//
//  EraserPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import PaletteView
import UIKit

fileprivate let initializeAlphas: [Int] = [
    255,
    225,
    200,
    175,
    150,
    125,
    100,
    50
]

final class EraserPalette: ObservableObject, AlphaPaletteDisplayProtocol {

    private(set) var id: UUID

    @Published private(set) var items: [AlphaPaletteItem] = []
    @Published private(set) var selectedIndex: Int = 0

    var alphas: [Int] {
        items.map(\.alpha)
    }

    var index: Int {
        selectedIndex
    }

    public init(
        id: UUID = UUID(),
        alphas: [Int] = initializeAlphas,
        index: Int = 0
    ) {
        self.id = id

        let newAlphas = alphas.isEmpty ? [255] : alphas
        self.items = Self.makeItems(from: newAlphas)
        self.selectedIndex = max(0, min(index, newAlphas.count - 1))
    }
}

extension EraserPalette {

    func initializeData() {
        items = Self.makeItems(from: initializeAlphas)
        selectedIndex = 0
    }

    func setId(_ id: UUID) {
        self.id = id
    }

    var alpha: Int? {
        items.indices.contains(selectedIndex) ? items[selectedIndex].alpha : nil
    }

    func alpha(at index: Int) -> Int? {
        items.indices.contains(index) ? items[index].alpha : nil
    }

    @discardableResult
    func select(_ index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        let didReselect = selectedIndex == index
        selectedIndex = index
        return didReselect
    }

    func insert(_ alpha: Int, at index: Int) {
        guard (0 ... items.count).contains(index) else { return }
        items.insert(AlphaPaletteItem(alpha: alpha), at: index)
    }

    func update(
        alphas: [Int] = [],
        index: Int = 0
    ) {
        let newAlphas = alphas.isEmpty ? [255] : alphas
        items = Self.makeItems(from: newAlphas)
        selectedIndex = max(0, min(index, newAlphas.count - 1))
    }

    func update(
        alpha: Int,
        at index: Int
    ) {
        guard items.indices.contains(index) else { return }
        items[index] = AlphaPaletteItem(id: items[index].id, alpha: alpha)
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) && items.count > 1 else { return }
        items.remove(at: index)
    }
}

private extension EraserPalette {
    static func makeItems(from alphas: [Int]) -> [AlphaPaletteItem] {
        alphas.map { AlphaPaletteItem(alpha: $0) }
    }
}
