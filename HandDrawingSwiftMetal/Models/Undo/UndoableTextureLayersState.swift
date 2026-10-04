//
//  Created by Eisuke Kusachi
//

import Foundation
import TextureLayerView

/// `TextureLayersState` that records layer edits for undo.
@MainActor
final class UndoableTextureLayersState: TextureLayersState {

    private var undo: UndoTextureLayerRegistrar?

    func setUndo(undo: UndoTextureLayerRegistrar) {
        self.undo = undo
    }

    override func addLayer() async throws {
        guard let undo else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Undo is not set")
            )
        }
        let count = layerModels.count
        try await super.addLayer()
        guard layerModels.count > count else { return }
        await undo.addLayer(in: self)
    }

    override func removeLayer(id: LayerId) async throws -> Bool {
        guard let undo else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Undo is not set")
            )
        }
        return try await undo.removeLayer(in: self, id: id) {
            try await super.removeLayer(id: id)
        }
    }

    override func renameLayer(id: LayerId, title: String) throws {
        guard let undo else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Undo is not set")
            )
        }
        try undo.renameLayer(in: self, id: id, title: title) {
            try super.renameLayer(id: id, title: title)
        }
    }

    override func moveLayers(from source: IndexSet, to destination: Int) throws {
        guard let undo else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Undo is not set")
            )
        }
        try undo.moveLayer(in: self, source: source, destination: destination) {
            try super.moveLayers(from: source, to: destination)
        }
    }

    override func selectLayer(id: LayerId) throws {
        guard let undo else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Undo is not set")
            )
        }
        try undo.selectLayer(in: self, id: id) {
            try super.selectLayer(id: id)
        }
    }

    override func setVisibility(id: LayerId, isVisible: Bool) throws {
        guard let undo else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Undo is not set")
            )
        }
        try undo.changeVisibility(in: self, id: id, isVisible: isVisible) {
            try super.setVisibility(id: id, isVisible: isVisible)
        }
    }

    override func setAlphaSliderDragging(_ isDragging: Bool) {
        undo?.alphaSliderDraggingChanged(in: self, isDragging)
    }
}
