//
//  EraserPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import PaletteEditView
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

@MainActor
final class EraserPalette: ObservableObject, AlphaPaletteDisplayProtocol, AlphaPaletteEditViewProtocol {

    private(set) var id: UUID

    @Published private(set) var items: [AlphaPaletteItem] = []
    @Published private(set) var selectedIndex: Int = 0

    public init(
        id: UUID = UUID(),
        alphas: [Int] = initializeAlphas,
        selectedIndex: Int = 0
    ) {
        self.id = id

        let newAlphas = alphas.isEmpty ? [255] : alphas
        self.items = Self.makeItems(from: newAlphas)
        self.selectedIndex = max(0, min(selectedIndex, newAlphas.count - 1))
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

    var selectedAlpha: Int {
        alpha ?? 255
    }

    var canRemoveSelected: Bool {
        items.count > 1
    }

    func alpha(at index: Int) -> Int? {
        items.indices.contains(index) ? items[index].alpha : nil
    }

    func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
    }

    func insert(_ alpha: Int, at index: Int) {
        guard (0 ... items.count).contains(index) else { return }
        items.insert(AlphaPaletteItem(alpha: alpha), at: index)
    }

    func update(
        alphas: [Int] = [],
        selectedIndex: Int = 0
    ) {
        let newAlphas = alphas.isEmpty ? [255] : alphas
        items = Self.makeItems(from: newAlphas)
        self.selectedIndex = max(0, min(selectedIndex, newAlphas.count - 1))
    }

    func update(
        alpha: Int,
        at index: Int? = nil
    ) {
        let index = index ?? selectedIndex
        guard items.indices.contains(index) else { return }
        items[index] = AlphaPaletteItem(id: items[index].id, alpha: alpha)
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

    func removeSelected() {
        remove(at: selectedIndex)
    }

    func duplicateSelected() {
        guard let alpha else { return }
        insert(alpha, at: selectedIndex + 1)
    }
}

private extension EraserPalette {
    static func makeItems(from alphas: [Int]) -> [AlphaPaletteItem] {
        alphas.map { AlphaPaletteItem(alpha: $0) }
    }
}
