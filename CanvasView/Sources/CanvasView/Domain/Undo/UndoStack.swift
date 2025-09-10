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

    private let undoManager = UndoManager()

    private let textureLayers: TextureLayers

    private let textureRepository: TextureRepository!

    private let undoTextureRepository: TextureRepository

    /// An undo object captured at the start of the stroke, shown when undo is triggered.
    private var drawingUndoObject: UndoObject?

    private var cancellables = Set<AnyCancellable>()

    init(
        undoCount: Int = 64,
        textureLayers: TextureLayers,
        textureRepository: TextureRepository,
        undoTextureRepository: TextureRepository
    ) {
        self.textureLayers = textureLayers

        self.textureRepository = textureRepository
        self.undoTextureRepository = undoTextureRepository

        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false

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
            let textureLayerId = textureLayers.selectedLayerId,
            let undoLayer = textureLayers.selectedLayer
        else { return }

        let undoObject = UndoDrawingObject(
            from: .init(item: undoLayer)
        )

        do {
            let result = try await textureRepository
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
        texture: MTLTexture
    ) async {
        guard
            let undoObject = drawingUndoObject,
            let redoLayer = textureLayers.selectedLayer
        else { return }

        let redoObject = UndoDrawingObject(
            from: .init(item: redoLayer)
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
        texture: MTLTexture
    ) async {
        guard
            let undoObject = drawingUndoObject,
            let redoLayer = textureLayers.selectedLayer
        else { return }

        let redoObject = UndoDrawingObject(
            from: .init(item: redoLayer)
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
                self?.undoTextureRepository.removeTexture(
                    result.undoTextureUUID
                )
            })
            .store(in: &cancellables)

        redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                self?.undoTextureRepository.removeTexture(
                    result.undoTextureUUID
                )
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
        undoManager.registerUndo(withTarget: self) { _ in
            Task { @MainActor [weak self] in
                self?.performUndo(undoStack.undoObject)

                // Redo Registration
                self?.pushUndoObject(undoStack.reversedObject)
            }
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
                    textureRepository: textureRepository,
                    undoTextureRepository: undoTextureRepository
                )

                try await didPerformUndo(
                    undoObject: undoObject,
                    textureRepository: textureRepository
                )
            } catch {
                Logger.error(error)
            }
        }
    }

    private func didPerformUndo(
        undoObject: UndoObject,
        textureRepository: TextureRepository
    ) async throws {
        /*
        if let undoObject = undoObject as? UndoDrawingObject {
            let result = try await textureRepository.copyTexture(uuid: undoObject.textureLayer.id)

            textureLayers.updateThumbnail(result)
            textureLayers.selectedLayerId = undoObject.textureLayer.id
            textureLayers.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoAdditionObject {
            let result = try await textureRepository.copyTexture(uuid: undoObject.textureLayer.id)

            textureLayers.addLayer(
                newTextureLayer: .init(model: undoObject.textureLayer, thumbnail: nil),
                at: undoObject.insertIndex
            )
            textureLayers.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoDeletionObject {
            textureLayers.removeLayer(
                layerIdToDelete: undoObject.textureLayer.id,
                newLayerId: undoObject.selectedLayerIdAfterDeletion
            )
            textureLayers.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoMoveObject {
            textureLayers.moveLayer(
                indices: undoObject.indices,
                selectedLayerId: undoObject.selectedLayerId
            )
            textureLayers.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoAlphaChangedObject {
            let result = try await textureRepository.copyTexture(uuid: undoObject.textureLayer.id)

            textureLayers.updateLayer(
                newTextureLayer: .init(model: undoObject.textureLayer, thumbnail: nil)
            )
            textureLayers.canvasUpdateSubject.send()
        }
        */
    }
}
