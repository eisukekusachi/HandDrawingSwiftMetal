//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// A store that manages the layer stack of a canvas
public final class TextureLayers: ObservableObject {

    /// Subject to publish updates for the canvas
    public let canvasUpdateSubject = PassthroughSubject<Void, Never>()

    /// Subject to publish updates for the entire canvas, including all textures
    public let fullCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private var textureRepository: TextureRepository?

    private var undoStack: UndoStack?

    @Published public var layers: [TextureLayerItem] = []

    @Published public var selectedLayerId: UUID?

    // Set a default value to avoid nil
    @Published private(set) var textureSize: CGSize = .init(width: 768, height: 1024)

    private var oldAlpha: Int?

    public init() {}
}

public extension TextureLayers {

    // Add a computed property for cross-package access
    var currentTextureSize: CGSize {
        textureSize
    }

    var selectedLayer: TextureLayerItem? {
        guard let selectedLayerId else { return nil }
        return layers.first(where: { $0.id == selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    func layer(_ layerId: UUID) -> TextureLayerItem? {
        layers.first(where: { $0.id == layerId })
    }
}

@MainActor
public extension TextureLayers {

    func initialize(
        configuration: ResolvedCanvasConfiguration,
        textureRepository: TextureRepository? = nil,
        undoStack: UndoStack? = nil
    ) async {
        self.textureSize = configuration.textureSize

        self.layers = configuration.layers.map {
            .init(
                id: $0.id,
                title: $0.title,
                alpha: $0.alpha,
                isVisible: $0.isVisible,
                thumbnail: nil
            )
        }

        self.selectedLayerId = configuration.selectedLayerId

        self.textureRepository = textureRepository

        Task {
            let results = try await textureRepository?.copyTextures(uuids: layers.map { $0.id })
            self.updateAllThumbnails(results ?? [])
        }
    }

    func addLayer(newTextureLayer textureLayer: TextureLayerItem, texture: MTLTexture?, at index: Int) async throws {
        guard
            let textureRepository,
            let previousLayerIndex = selectedIndex
        else { return }

        self.layers.insert(textureLayer, at: index)

        selectLayer(id: textureLayer.id)

        try await textureRepository
            .addTexture(
                texture,
                newTextureUUID: textureLayer.id
            )

        if let currentLayerIndex = selectedIndex {
            await self.addUndoAdditionObject(
                previousLayerIndex: previousLayerIndex,
                currentLayerIndex: currentLayerIndex,
                layer: .init(item: textureLayer),
                texture: texture
            )
        }
    }

    func removeLayer(layerIdToDelete index: Int) async throws {
        guard
            let textureRepository,
            let selectedLayerId,
            let selectedLayer,
            let selectedIndex
        else { return }

        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: index)

        layers.remove(at: index)

        try? await Task.sleep(nanoseconds: 10_000_000)

        selectLayer(id: layers[newLayerIndex].id)

        let result = try await textureRepository.copyTexture(
            uuid: selectedLayerId
        )

        await addUndoDeletionObject(
            previousLayerIndex: selectedIndex,
            currentLayerIndex: newLayerIndex,
            layer: .init(
                fileName: selectedLayer.fileName,
                title: selectedLayer.title,
                alpha: selectedLayer.alpha,
                isVisible: selectedLayer.isVisible
            ),
            texture: result.texture
        )

        textureRepository
            .removeTexture(selectedLayer.id)
    }

    func moveLayer(indices: MoveLayerIndices) {
        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: self.layers.count
        )

        self.layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )

        fullCanvasUpdateSubject.send(())

        guard
            let selectedLayerId = selectedLayer?.id,
            let textureLayer = layers.first(where: { $0.id == selectedLayerId })
        else { return }

        addUndoMoveObject(
            indices: MoveLayerIndices.reversedIndices(
                indices: indices,
                layerCount: layers.count
            ),
            selectedLayerId: selectedLayerId,
            textureLayer: .init(
                fileName: textureLayer.fileName,
                title: textureLayer.title,
                alpha: textureLayer.alpha,
                isVisible: textureLayer.isVisible
            )
        )
    }

    func updateLayer(
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard
            let selectedIndex = layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = layers[selectedIndex]

        if let title {
            layers[selectedIndex] = .init(
                id: layer.id,
                title: title,
                alpha: layer.alpha,
                isVisible: layer.isVisible,
                thumbnail: layer.thumbnail
            )
        }
        if let isVisible {
            layers[selectedIndex] = .init(
                id: layer.id,
                title: layer.title,
                alpha: layer.alpha,
                isVisible: isVisible,
                thumbnail: layer.thumbnail
            )

            // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
            fullCanvasUpdateSubject.send(())
        }
        if let alpha {
            layers[selectedIndex] = .init(
                id: layer.id,
                title: layer.title,
                alpha: alpha,
                isVisible: layer.isVisible,
                thumbnail: layer.thumbnail
            )

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            canvasUpdateSubject.send(())
        }
    }

    func updateThumbnail(_ identifiedTexture: IdentifiedTexture) {
        guard let index = layers.firstIndex(where: { $0.id == identifiedTexture.uuid }) else { return }
        self.layers[index].thumbnail = identifiedTexture.texture.makeThumbnail()
    }

    func updateAllThumbnails(_ identifiedTextures: [IdentifiedTexture]) {
        for identifiedTexture in identifiedTextures {
            updateThumbnail(identifiedTexture)
        }
    }

    func selectLayer(id: UUID) {
        selectedLayerId = id
        fullCanvasUpdateSubject.send(())
    }
}

@MainActor
public extension TextureLayers {

    func addUndoAlphaObject(dragging: Bool) {
        if dragging, let alpha = selectedLayer?.alpha {
            self.oldAlpha = alpha

        } else {
            if let oldAlpha = self.oldAlpha,
               let newAlpha = selectedLayer?.alpha,
               let selectedLayer = selectedLayer {

                let undoObject = UndoAlphaChangedObject(
                    layer: .init(item: selectedLayer),
                    withNewAlpha: Int(oldAlpha)
                )

                undoStack?.pushUndoObject(
                    .init(
                        undoObject: undoObject,
                        redoObject: UndoAlphaChangedObject(
                            layer: undoObject.textureLayer,
                            withNewAlpha: newAlpha
                        )
                    )
                )
            }
            self.oldAlpha = nil
        }
    }

    func addUndoAdditionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) async {
        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            insertIndex: currentLayerIndex
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: layers[previousLayerIndex].id
        )

        await undoStack?.pushUndoAdditionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    func addUndoDeletionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) async {
        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: layers[currentLayerIndex].id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            layerToBeAdded: redoObject.textureLayer,
            insertIndex: previousLayerIndex
        )

        await undoStack?.pushUndoDeletionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    func addUndoMoveObject(
        indices: MoveLayerIndices,
        selectedLayerId: UUID,
        textureLayer: TextureLayerModel
    ) {
        let redoObject = UndoMoveObject(
            indices: indices,
            selectedLayerId: selectedLayerId,
            layer: textureLayer
        )

        let undoObject = redoObject.reversedObject

        undoStack?.pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }
}
