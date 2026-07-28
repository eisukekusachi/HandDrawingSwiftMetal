//
//  EraserPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import PaletteEditView
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

final class EraserPalette: ObservableObject, AlphaPaletteAlphaSource {

    static let minAlphaCount = 1
    static let maxAlphaCount = 64

    private(set) var id: UUID

    var selectedAlpha: Int {
        alpha ?? 255
    }

    @Published private(set) var alphas: [Int] = []
    @Published private(set) var selectedIndex: Int = 0

    public init(
        id: UUID = UUID(),
        alphas: [Int] = initializeAlphas,
        selectedIndex: Int = 0
    ) {
        self.id = id

        let newAlphas = alphas.isEmpty ? [255] : alphas
        self.alphas = newAlphas
        self.selectedIndex = max(0, min(selectedIndex, newAlphas.count - 1))
    }
}

extension EraserPalette {

    func initializeData() {
        self.alphas = initializeAlphas
        self.selectedIndex = 0
    }

    func setId(_ id: UUID) {
        self.id = id
    }

    var alpha: Int? {
        guard selectedIndex < alphas.count else { return nil }
        return alphas[selectedIndex]
    }

    var canDuplicateSelected: Bool {
        alphas.count < Self.maxAlphaCount && alpha != nil
    }

    var canRemoveSelected: Bool {
        alphas.count > Self.minAlphaCount
    }

    func alpha(at index: Int) -> Int? {
        self.alphas.indices.contains(index) ? alphas[index] : nil
    }

    @discardableResult
    func select(_ index: Int) -> Bool {
        guard alphas.indices.contains(index) else { return false }
        let didReselect = selectedIndex == index
        selectedIndex = index
        return didReselect
    }

    func insert(_ alpha: Int, at index: Int) {
        guard
            alphas.count < Self.maxAlphaCount,
            (0 ... alphas.count).contains(index)
        else { return }
        var updated = alphas
        updated.insert(alpha, at: index)
        alphas = updated
    }

    func duplicateSelected() {
        guard canDuplicateSelected, let alpha else { return }
        insert(alpha, at: selectedIndex + 1)
    }

    func update(
        alphas: [Int] = [],
        selectedIndex: Int = 0
    ) {
        self.alphas = alphas.isEmpty ? [255] : alphas
        self.selectedIndex = max(0, min(selectedIndex, self.alphas.count - 1))
    }

    func update(
        alpha: Int,
        at index: Int
    ) {
        guard alphas.indices.contains(index) else { return }
        var updated = alphas
        updated[index] = alpha
        alphas = updated
    }

    func remove(at index: Int) {
        guard alphas.indices.contains(index) && alphas.count > Self.minAlphaCount else { return }
        var updated = alphas
        updated.remove(at: index)
        alphas = updated

        if selectedIndex > index {
            selectedIndex -= 1
        } else if selectedIndex >= updated.count {
            selectedIndex = updated.count - 1
        }
    }

    func removeSelected() {
        remove(at: selectedIndex)
    }
}
