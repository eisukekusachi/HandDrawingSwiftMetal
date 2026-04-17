//
//  HandDrawingCanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/02/04.
//

import CanvasView
import Combine
import Foundation
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class HandDrawingCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    let performUndoSubject = PassthroughSubject<UndoObject, Never>()

    let updateCanvasTextureSubject = PassthroughSubject<MTLTexture?, Never>()

    let updateFullCanvasTextureSubject = PassthroughSubject<Void, Never>()

    let textureLayersState: TextureLayersState

    let undoDrawing: UndoDrawing?

    private let dependencies: HandDrawingCanvasViewDependencies

    private var cancellables = Set<AnyCancellable>()

    private var renderer: MTLRendering

    init(
        textureLayersState: TextureLayersState,
        renderer: MTLRendering,
        dependencies: HandDrawingCanvasViewDependencies? = nil
    ) {
        self.textureLayersState = textureLayersState
        self.dependencies = dependencies ?? .init()
        self.renderer = renderer
        self.undoDrawing = .init(
            renderer: self.renderer,
            inMemoryRepository: self.dependencies.undoTextureInMemoryRepository
        )
    }
}

extension HandDrawingCanvasViewModel {

    func performDrawingUndo(
        _ undoObject: UndoDrawingObject
    ) async {
        guard
            let undoTextureId = undoObject.undoTextureId,
            let newTexture = try? await MTLTextureCreator.duplicateTexture(
                texture: dependencies.undoTextureInMemoryRepository.texture(undoTextureId),
                renderer: renderer
            )
        else { return }

        do {
            let textureLayerId = undoObject.textureLayer.id
            textureLayersState.selectLayer(textureLayerId)

            let textureData = try await newTexture.data(
                device: renderer.device,
                commandQueue: renderer.commandQueue
            )
            try await saveTextureToDocumentsDirectory(
                layerId: textureLayerId,
                textureData: textureData
            )
            textureLayersState.updateThumbnail(textureLayerId, texture: newTexture)

            updateCanvasTextureSubject.send(newTexture)

        } catch {
            Logger.error(error)
        }
    }

    func performAdditionUndo(
        _ undoObject: UndoAdditionObject
    ) async {
        guard
            let undoTextureId = undoObject.undoTextureId,
            let newTexture = try? await MTLTextureCreator.duplicateTexture(
                texture: dependencies.undoTextureInMemoryRepository.texture(undoTextureId),
                renderer: renderer
            )
        else { return }

        do {
            let textureData = try await newTexture.data(
                device: renderer.device,
                commandQueue: renderer.commandQueue
            )
            try await saveTextureToDocumentsDirectory(
                layerId: undoObject.textureLayer.id,
                textureData: textureData
            )

            textureLayersState.addLayer(
                layer: undoObject.textureLayer,
                thumbnail: newTexture.makeThumbnail(),
                at: undoObject.insertIndex
            )

            updateFullCanvasTextureSubject.send()

        } catch {
            Logger.error(error)
        }
    }

    func performDeletionUndo(
        _ undoObject: UndoDeletionObject
    ) {
        guard
            let index = textureLayersState.layers.firstIndex(
                where: { $0.id == undoObject.textureLayer.id }
            )
        else {
           return
        }

        textureLayersState.removeLayer(
            layerIndexToDelete: index
        )
        updateFullCanvasTextureSubject.send()
    }

    func performMoveUndo(
        _ undoObject: UndoMoveObject
    ) {
        textureLayersState.moveLayer(
            indices: undoObject.indices
        )
        updateFullCanvasTextureSubject.send()
    }

    func performSelectUndo(
        _ undoObject: UndoSelectionObject
    ) async {
        textureLayersState.selectLayer(
            undoObject.textureLayer.id
        )
        updateFullCanvasTextureSubject.send()
    }

    func performAlphaUndo(
        _ undoObject: UndoAlphaObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            alpha: undoObject.textureLayer.alpha
        )
        updateCanvasTextureSubject.send(nil)
    }

    func performVisibilityUndo(
        _ undoObject: UndoVisibilityObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            isVisible: undoObject.textureLayer.isVisible
        )
        updateFullCanvasTextureSubject.send()
    }

    func performTitleUndo(
        _ undoObject: UndoTitleObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            title: undoObject.textureLayer.title
        )
    }

    func registerUndoObjectPair(
        _ undoManager: UndoManager,
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        undoRedoObject.undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                Task {
                    // Do nothing if an error occurs, since nothing can be done
                    try? await self.dependencies.undoTextureInMemoryRepository.removeTexture(
                        undoTextureId
                    )
                }
            })
            .store(in: &cancellables)

        undoRedoObject.redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                Task {
                    // Do nothing if an error occurs, since nothing can be done
                    try? await self.dependencies.undoTextureInMemoryRepository.removeTexture(
                        undoTextureId
                    )
                }
            })
            .store(in: &cancellables)

        undoManager.registerUndo(withTarget: self) { [weak self, undoRedoObject] _ in
            self?.performUndoSubject.send(undoRedoObject.undoObject)

            // Redo Registration
            self?.registerUndoObjectPair(undoManager, undoRedoObject.reversed())
        }
    }

    func clearUndoTextures() {
        Task { [weak self] in
            await self?.dependencies.undoTextureInMemoryRepository.removeAll()
        }
    }

    func duplicateTextureFromDocumentsDirectory(
        _ id: LayerId
    ) async -> MTLTexture? {
        await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            textureSize: textureSize,
            device: renderer.device
        )
    }

    func duplicateTexturesFromDocumentsDirectory(
        _ ids: [LayerId]
    ) async -> [(LayerId, MTLTexture)] {
        await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            textureSize: textureSize,
            device: renderer.device
        )
    }
}

extension HandDrawingCanvasViewModel {

    func saveTextureToDocumentsDirectory(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await dependencies.textureLayersDocumentsRepository.writeDataToDisk(
            id: layerId,
            data: textureData
        )
    }
}
