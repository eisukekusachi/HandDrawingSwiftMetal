//
//  UndoCoordinator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/18.
//

import CanvasView
import Combine
import Foundation
import TextureLayerCanvasView
import TextureLayerView

@MainActor
final class UndoCoordinator {

    private(set) var undoManager: UndoManager?

    var didUndo: AnyPublisher<Void, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private let didUndoSubject = PassthroughSubject<Void, Never>()

    private let canvasView: TextureLayerCanvasView

    private let textureLayersState: TextureLayersState

    private let undoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol = UndoTextureInMemoryRepository.shared

    private var cancellables = Set<AnyCancellable>()

    private var undoDrawing: UndoDrawing?

    init(
        canvasView: TextureLayerCanvasView,
        textureLayersState: TextureLayersState
    ) {
        self.canvasView = canvasView
        self.textureLayersState = textureLayersState
        self.undoDrawing = .init(
            renderer: canvasView.renderer,
            inMemoryRepository: undoTextureInMemoryRepository
        )
    }

    func setUndoManager(_ undoManager: UndoManager?) {
        // Set an initial value to prevent out-of-memory errors when no limit is applied
        if undoManager?.levelsOfUndo == 0 {
            undoManager?.levelsOfUndo = 8
        }

        self.undoManager = undoManager
    }

    func initializeDrawingUndoTextures(_ textureSize: CGSize) async {
        // Initialize the textures used for Undo
        undoDrawing?.initializeUndoTextures(
            textureSize: textureSize
        )
        await resetUndo()
    }

    func undo() {
        guard let undoManager else { return }
        undoManager.undo()
        didUndoSubject.send()
    }
    func redo() {
        guard let undoManager else { return }
        undoManager.redo()
        didUndoSubject.send()
    }
    func resetUndo() async {
        guard let undoManager else { return }
        await undoTextureInMemoryRepository.removeAll()
        undoManager.removeAllActions()
        didUndoSubject.send()
    }
}

extension UndoCoordinator {
    func registerDrawingUndoAfterCompletion(_ event: StrokeEvent) {
        switch event {
        case .fingerStrokeBegan, .pencilStrokeBegan:
            Task {
                await undoDrawing?.setUndoDrawing(
                    texture: canvasView.currentTexture
                )
            }
        case .strokeCompleted:
            Task {
                guard
                    let selectedLayer = textureLayersState.selectedLayer,
                    let undoRedoObjectPair = try await undoDrawing?.pushUndoDrawingObject(
                        selectedLayer: selectedLayer,
                        texture: canvasView.currentTexture
                    )
                else {
                    return
                }
                registerUndo(undoRedoObjectPair)
            }
        case .strokeCancelled:
            break
        }
    }

    func registerUndo(
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        guard let undoManager else { return }

        undoRedoObject.undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                Task {
                    // Do nothing if an error occurs, since nothing can be done
                    try? await self.undoTextureInMemoryRepository.removeTexture(
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
                    try? await self.undoTextureInMemoryRepository.removeTexture(
                        undoTextureId
                    )
                }
            })
            .store(in: &cancellables)

        undoManager.registerUndo(withTarget: self) { [weak self, undoRedoObject] _ in
            self?.performUndo(undoRedoObject.undoObject)

            // Redo Registration
            self?.registerUndo(undoRedoObject.reversed())
        }

        didUndoSubject.send()
    }

    func performUndo(_ undoObject: UndoObject) {
        Task { [weak self] in
            if let undoObject = undoObject as? UndoDrawingObject {
                await self?.performDrawingUndo(undoObject)
            } else if let undoObject = undoObject as? UndoAdditionObject {
                await self?.performAdditionUndo(undoObject)
            } else if let undoObject = undoObject as? UndoDeletionObject {
                self?.performDeletionUndo(undoObject)
            } else if let undoObject = undoObject as? UndoSelectionObject {
                await self?.performSelectUndo(undoObject)
            } else if let undoObject = undoObject as? UndoMoveObject {
                self?.performMoveUndo(undoObject)
            } else if let undoObject = undoObject as? UndoAlphaObject {
                await self?.performAlphaUndo(undoObject)
            } else if let undoObject = undoObject as? UndoVisibilityObject {
                await self?.performVisibilityUndo(undoObject)
            } else if let undoObject = undoObject as? UndoTitleObject {
                await self?.performTitleUndo(undoObject)
            }
        }
    }
}

private extension UndoCoordinator {
    func performDrawingUndo(
        _ undoObject: UndoDrawingObject
    ) async {
        guard
            let undoTextureId = undoObject.undoTextureId,
            let newTexture = try? await MTLTextureCreator.duplicateTexture(
                texture: undoTextureInMemoryRepository.texture(undoTextureId),
                renderer: canvasView.renderer
            )
        else { return }

        do {
            let textureLayerId = undoObject.textureLayer.id
            textureLayersState.selectLayer(textureLayerId)

            let textureData = try await newTexture.data(
                device: canvasView.renderer.device,
                commandQueue: canvasView.renderer.commandQueue
            )

            try await canvasView.saveTextureToDocumentsDirectory(
                layerId: textureLayerId,
                textureData: textureData
            )
            textureLayersState.updateThumbnail(textureLayerId, texture: newTexture)

            try? canvasView.setCurrentTexture(newTexture)
            canvasView.updateCanvasTextureUsingCurrentTexture()

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
                texture: undoTextureInMemoryRepository.texture(undoTextureId),
                renderer: canvasView.renderer
            )
        else { return }

        do {
            let textureData = try await newTexture.data(
                device: canvasView.renderer.device,
                commandQueue: canvasView.renderer.commandQueue
            )
            try await canvasView.saveTextureToDocumentsDirectory(
                layerId: undoObject.textureLayer.id,
                textureData: textureData
            )

            textureLayersState.addLayer(
                layer: undoObject.textureLayer,
                thumbnail: newTexture.makeThumbnail(),
                at: undoObject.insertIndex
            )

            try? await canvasView.updateFullCanvasTexture()

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

        Task {
            try? await canvasView.updateFullCanvasTexture()
        }
    }

    func performMoveUndo(
        _ undoObject: UndoMoveObject
    ) {
        textureLayersState.moveLayer(
            indices: undoObject.indices
        )

        Task {
            try? await canvasView.updateFullCanvasTexture()
        }
    }

    func performSelectUndo(
        _ undoObject: UndoSelectionObject
    ) async {
        textureLayersState.selectLayer(
            undoObject.textureLayer.id
        )

        try? await canvasView.updateFullCanvasTexture()
    }

    func performAlphaUndo(
        _ undoObject: UndoAlphaObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            alpha: undoObject.textureLayer.alpha
        )

        canvasView.updateCanvasTextureUsingCurrentTexture()
    }

    func performVisibilityUndo(
        _ undoObject: UndoVisibilityObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            isVisible: undoObject.textureLayer.isVisible
        )

        try? await canvasView.updateFullCanvasTexture()
    }

    func performTitleUndo(
        _ undoObject: UndoTitleObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            title: undoObject.textureLayer.title
        )
    }
}
