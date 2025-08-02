//
//  UndoStack.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Combine
import Foundation
import MetalKit

@MainActor
public final class UndoStack {

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private let didUndoSubject: PassthroughSubject<UndoRedoButtonState, Never> = .init()

    @MainActor private let undoManager = UndoManager()

    private let canvasState: CanvasState

    private let textureLayerRepository: TextureLayerRepository!

    private let undoTextureRepository: TextureRepository

    /// An undo object captured at the start of the stroke, shown when undo is triggered.
    private var drawingUndoObject: UndoObject?

    private var cancellables = Set<AnyCancellable>()

    init(
        undoCount: Int = 64,
        canvasState: CanvasState,
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) {
        self.canvasState = canvasState

        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false

        self.textureLayerRepository = textureLayerRepository
        self.undoTextureRepository = undoTextureRepository

        didUndoSubject.send(.init(undoManager))
    }

    func initialize(_ size: CGSize) {
        reset()
        undoTextureRepository.setTextureSize(size)
    }

    func undo() {
        undoManager.undo()
        didUndoSubject.send(.init(undoManager))
    }
    func redo() {
        undoManager.redo()
        didUndoSubject.send(.init(undoManager))
    }
    func reset() {
        undoManager.removeAllActions()
        undoTextureRepository.removeAll()
        didUndoSubject.send(.init(undoManager))
    }
}

public extension UndoStack {

    func setDrawingUndoObject() async {
        guard
            let textureLayerId = canvasState.selectedLayerId,
            let undoLayer = canvasState.selectedLayer
        else { return }

        let undoObject = UndoDrawingObject(
            layer: .init(model: undoLayer)
        )

        do {
            let result = try await textureLayerRepository
                .copyTexture(uuid: textureLayerId)

            try await undoTextureRepository.addTexture(
                result.texture,
                newTextureUUID: undoObject.undoTextureUUID
            )

            drawingUndoObject = undoObject

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDrawingObjectAsync(
        canvasState: CanvasState,
        texture: MTLTexture
    ) async {
        guard
            let undoObject = drawingUndoObject,
            let redoLayer = canvasState.selectedLayer
        else { return }

        let redoObject = UndoDrawingObject(
            layer: .init(model: redoLayer)
        )

        do {
            try await undoTextureRepository
                .addTexture(
                    texture,
                    newTextureUUID: redoObject.undoTextureUUID
                )

            pushUndoObject(
                .init(
                    undoObject: undoObject,
                    redoObject: redoObject
                )
            )

            drawingUndoObject = nil

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDrawingObject(
        canvasState: CanvasState,
        texture: MTLTexture
    ) async {
        guard
            let undoObject = drawingUndoObject,
            let redoLayer = canvasState.selectedLayer
        else { return }

        let redoObject = UndoDrawingObject(
            layer: .init(model: redoLayer)
        )

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository
                .addTexture(
                    texture,
                    newTextureUUID: redoObject.undoTextureUUID
                )

            pushUndoObject(
                .init(
                    undoObject: undoObject,
                    redoObject: redoObject
                )
            )

            drawingUndoObject = nil

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoAdditionObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) async {
        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository
                .addTexture(
                    undoRedoObject.texture,
                    newTextureUUID: undoRedoObject.redoObject.undoTextureUUID
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDeletionObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) async {
        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository
                .addTexture(
                    undoRedoObject.texture,
                    newTextureUUID: undoRedoObject.undoObject.undoTextureUUID
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) {
        let undoObject = undoRedoObject.undoObject
        let redoObject = undoRedoObject.redoObject

        undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                do {
                    try self?.undoTextureRepository.removeTexture(
                        result.undoTextureUUID
                    )
                } catch {
                    Logger.error(error)
                }
            })
            .store(in: &cancellables)

        redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                do {
                    try self?.undoTextureRepository.removeTexture(
                        result.undoTextureUUID
                    )
                } catch {
                    Logger.error(error)
                }
            })
            .store(in: &cancellables)

        pushUndoObjectToUndoStack(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }
}

extension UndoStack {

    private func pushUndoObjectToUndoStack(
        _ undoStack: UndoStackModel<UndoObject>
    ) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.performUndo(undoStack.undoObject)

            // Redo Registration
            self?.pushUndoObject(undoStack.reversedObject)
        }
        undoManager.endUndoGrouping()
        didUndoSubject.send(.init(undoManager))
    }

    private func performUndo(
        _ undoObject: UndoObject
    ) {
        Task {
            do {
                try await undoObject.performTextureOperation(
                    textureLayerRepository: textureLayerRepository,
                    undoTextureRepository: undoTextureRepository
                )
                completeUndoAction(undoObject)
            } catch {
                Logger.error(error)
            }
        }
    }

    private func completeUndoAction(_ undoObject: UndoObject) {
        if let undoObject = undoObject as? UndoDrawingObject {
            canvasState.selectedLayerId = undoObject.textureLayer.id
            canvasState.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoAdditionObject {
            canvasState.addLayer(
                newTextureLayer: .init(item: undoObject.textureLayer),
                at: undoObject.insertIndex
            )
            canvasState.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoDeletionObject {
            canvasState.removeLayer(
                textureLayer: .init(item: undoObject.textureLayer),
                newSelectedLayerId: undoObject.selectedLayerIdAfterDeletion
            )
            canvasState.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoMoveObject {
            canvasState.moveLayer(
                indices: undoObject.indices,
                selectedLayerId: undoObject.selectedLayerId
            )
            canvasState.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoAlphaChangedObject {
            canvasState.updateLayer(
                newTextureLayer: .init(item: undoObject.textureLayer)
            )
            canvasState.canvasUpdateSubject.send()
        }
    }
}
