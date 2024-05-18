//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/18.
//

import Foundation

class LayerManager<T: Equatable>: ObservableObject {

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

    func initLayers(
        index: Int,
        layers: [T]
    ) {
        self.layers = layers
        self.index = index
    }

    func addLayer(_ layer: T) {
        if index < layers.count - 1 {
            layers.insert(layer, at: index + 1)
        } else {
            layers.append(layer)
        }
    }

    func moveLayer(
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) {
        guard let selectedLayer else { return }

        layers = layers.reversed()
        layers.move(fromOffsets: source, toOffset: destination)
        layers = layers.reversed()

        updateIndex(selectedLayer)
    }

    func removeLayer(_ layer: T) {
        layers.removeAll { $0 == layer }

        // Update index for array bounds
        var newIndex = index
        if newIndex > layers.count - 1 {
            newIndex = layers.count - 1
        }
        index = newIndex
    }

    func updateIndex(_ layer: T?) {
        guard let layer, let layerIndex = layers.firstIndex(of: layer) else { return }
        index = layerIndex
    }

}
