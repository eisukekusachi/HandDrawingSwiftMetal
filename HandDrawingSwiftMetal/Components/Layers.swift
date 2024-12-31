//
//  Layers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

class Layers<T: Equatable>: ObservableObject {

    @Published var selectedLayer: T?

    var layers: [T] = [] {
        didSet {
            guard index < layers.count else { return }
            selectedLayer = layers[index]
        }
    }

    var index: Int = 0 {
        didSet {
            guard index < layers.count else { return }
            selectedLayer = layers[index]
        }
    }

    var count: Int {
        layers.count
    }

    func initLayers(
        index: Int,
        layers: [T]
    ) {
        self.layers = layers
        setIndex(index)
    }

    func setLayer(index: Int, layer: T) {
        layers[index] = layer
    }
    func getLayer(index: Int) -> T? {
        guard layers.indices.contains(index) else { return nil }
        return layers[index]
    }

    func getIndex(layer: T) -> Int? {
        layers.firstIndex(of: layer)
    }

    func setIndex(from layer: T) {
        index = layers.firstIndex(of: layer) ?? 0
    }

    func setIndex(_ newIndex: Int) {
        index = max(0, min(newIndex, layers.count - 1))
    }

}

extension Layers {

    var canDeleteLayer: Bool {
        layers.count > 1
    }

    func insertLayer(layer: T, at index: Int) {
        layers.insert(layer, at: index)
    }

    func removeLayer(at removeIndex: Int) {
        guard layers.indices.contains(removeIndex) else { return }
        layers.remove(at: removeIndex)
    }

    func removeLayer(_ layer: T) {
        layers.removeAll { $0 == layer }
    }

    func moveLayer(
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        layers.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func reverseLayers() {
        layers.reverse()
    }

}
