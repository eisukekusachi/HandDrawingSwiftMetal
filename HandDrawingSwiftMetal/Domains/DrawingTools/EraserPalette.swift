//
//  EraserPalette.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import UIKit

final class EraserPalette: ObservableObject {

    private(set) var id: UUID

    @Published private(set) var alphas: [Int] = []
    @Published private(set) var index: Int = 0

    public init(
        id: UUID = UUID(),
        alphas: [Int] = [255],
        index: Int = 0
    ) {
        self.id = id

        let newAlphas = alphas.isEmpty ? [255] : alphas
        self.alphas = newAlphas
        self.index = max(0, min(index, newAlphas.count - 1))
    }
}

extension EraserPalette {

    func setId(_ id: UUID) {
        self.id = id
    }

    var alpha: Int? {
        self.alphas.indices.contains(index) ? alphas[index] : nil
    }

    func alpha(at index: Int) -> Int? {
        self.alphas.indices.contains(index) ? alphas[index] : nil
    }

    func select(_ index: Int) {
        self.index = index
    }

    func insert(_ alpha: Int, at index: Int) {
        guard (0 ... alphas.count).contains(index) else { return }
        alphas.insert(alpha, at: index)
    }

    func update(
        alphas: [Int] = [],
        index: Int = 0
    ) {
        self.alphas = alphas.isEmpty ? [255] : alphas
        self.index = max(0, min(index, self.alphas.count - 1))
    }

    func update(
        alpha: Int,
        at index: Int
    ) {
        guard alphas.indices.contains(index) else { return }
        alphas[index] = alpha
    }

    func remove(at index: Int) {
        guard alphas.indices.contains(index) && alphas.count > 1 else { return }
        alphas.remove(at: index)
    }
}
