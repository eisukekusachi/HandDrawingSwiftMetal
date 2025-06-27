//
//  UndoStack.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Combine
import Foundation
import MetalKit

final class UndoStack {

    let undoButtonStateUpdateSubject: PassthroughSubject<Bool, Never> = .init()
    let redoButtonStateUpdateSubject: PassthroughSubject<Bool, Never> = .init()

    private let canvasState: CanvasState

    private let undoManager = UndoManager()

    private let textureLayerRepository: TextureLayerRepository!

    private let undoTextureRepository: TextureRepository

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

        refreshUndoRedoButtons()
    }

    func initialize(_ size: CGSize) {
        reset()
        undoTextureRepository.setTextureSize(size)
    }

    func undo() {
        undoManager.undo()
        refreshUndoRedoButtons()
    }
    func redo() {
        undoManager.redo()
        refreshUndoRedoButtons()
    }
    func reset() {
        undoManager.removeAllActions()
        undoTextureRepository.removeAll()
        refreshUndoRedoButtons()
    }

}

extension UndoStack {

    func setDrawingUndoObject() {
        guard
            let textureLayerId = canvasState.selectedLayerId,
            let undoLayer = canvasState.selectedLayer
        else { return }

        let undoObject = UndoDrawingObject(
            textureLayer: undoLayer
        )

        // Add a texture to the UndoTextureRepository for restoration
        textureLayerRepository
            .copyTexture(uuid: textureLayerId)
            .flatMap { [weak self] result in
                self?.undoTextureRepository.addTexture(
                    result.texture,
                    newTextureUUID: undoObject.undoTextureUUID
                )
                ?? Fail(error: TextureLayerError.failedToUnwrap).eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.drawingUndoObject = undoObject
                }
            )
            .store(in: &cancellables)
    }

    func pushUndoDrawingObject(
        canvasState: CanvasState,
        texture: MTLTexture
    ) {
        guard
            let undoObject = drawingUndoObject,
            let redoLayer = canvasState.selectedLayer
        else { return }

        let redoObject = UndoDrawingObject(
            textureLayer: redoLayer
        )

        // Add a texture to the UndoTextureRepository for restoration
        undoTextureRepository
            .addTexture(
                texture,
                newTextureUUID: redoObject.undoTextureUUID
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("pushUndoDrawingObject(canvasState:, texture:) undoTextureRepository.addTexture(, using:) \(error)")
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.pushUndoObject(
                        .init(undoObject: undoObject, redoObject: redoObject)
                    )
                    self?.drawingUndoObject = nil
                }
            )
            .store(in: &cancellables)
    }

    func pushUndoAdditionObject(
        _ undoRedoObject: UndoRedoObject
    ) {
        // Add a texture to the UndoTextureRepository for restoration
        undoTextureRepository
            .addTexture(
                undoRedoObject.texture,
                newTextureUUID: undoRedoObject.redoObject.undoTextureUUID
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("pushUndoAdditionObject(:) undoTextureRepository.addTexture(, using:) \(error)")
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.pushUndoObject(undoRedoObject)
                }
            )
            .store(in: &cancellables)
    }

    func pushUndoDeletionObject(
        _ undoRedoObject: UndoRedoObject
    ) {
        // Add a texture to the UndoTextureRepository for restoration
        undoTextureRepository
            .addTexture(
                undoRedoObject.texture,
                newTextureUUID: undoRedoObject.undoObject.undoTextureUUID
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("pushUndoDeletionObject(:) undoTextureRepository.addTexture(, using:) \(error)")
                    }
                },
                receiveValue: { [weak self] result in
                    self?.pushUndoObject(undoRedoObject)
                }
            )
            .store(in: &cancellables)
    }

    func pushUndoObject(
        _ undoRedoObject: UndoRedoObject
    ) {
        let undoObject = undoRedoObject.undoObject
        let redoObject = undoRedoObject.redoObject

        undoObject.deinitSubject
            .flatMap { [weak self] result -> AnyPublisher<UUID, Error> in
                self?.undoTextureRepository.removeTexture(
                    result.undoTextureUUID
                )
                ?? Fail(error: TextureLayerError.failedToUnwrap).eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("pushUndoObject(canvasState:, texture:) undoObject \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        redoObject.deinitSubject
            .flatMap { [weak self] result -> AnyPublisher<UUID, Error> in
                self?.undoTextureRepository.removeTexture(
                    result.undoTextureUUID
                )
                ?? Fail(error: TextureLayerError.failedToUnwrap).eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("pushUndoObject(canvasState:, texture:) redoObject \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

}

extension UndoStack {

    private func pushUndoObject(
        _ undoStack: UndoStackModel<UndoObject>
    ) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.performUndo(undoStack.undoObject)

            // Redo Registration
            self?.pushUndoObject(undoStack.reversedObject)
        }
        undoManager.endUndoGrouping()

        refreshUndoRedoButtons()
    }

    private func performUndo(
        _ undoObject: UndoObject
    ) {
        undoObject.updateTextureLayerRepositoryIfNeeded(
            textureLayerRepository,
            using: undoTextureRepository
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    Logger.standard.error("performUndo(:) \(error)")
                }
            },
            receiveValue: { [weak self] in
                self?.completeUndoAction(undoObject)
            }
        )
        .store(in: &cancellables)
    }

    private func completeUndoAction(_ undoObject: UndoObject) {
        if let undoObject = undoObject as? UndoDrawingObject {
            canvasState.selectedLayerId = undoObject.textureLayer.id
            canvasState.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoAdditionObject {
            canvasState.addLayer(
                newTextureLayer: undoObject.textureLayer,
                at: undoObject.insertIndex
            )
            canvasState.fullCanvasUpdateSubject.send()

        } else if let undoObject = undoObject as? UndoDeletionObject {
            canvasState.removeLayer(
                textureLayer: undoObject.textureLayer,
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
                newTextureLayer: undoObject.textureLayer
            )
            canvasState.canvasUpdateSubject.send()
        }

    }

    func refreshUndoRedoButtons() {
        undoButtonStateUpdateSubject.send(undoManager.canUndo)
        redoButtonStateUpdateSubject.send(undoManager.canRedo)
    }

}

enum UndoStackError: Error {
    case failedToUnwrap
}
