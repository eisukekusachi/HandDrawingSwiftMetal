//
//  UndoRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/11/16.
//

import MetalKit
import Combine

final class UndoRepository {

    var canUndoPublisher: AnyPublisher<Bool, Never> {
        canUndoSubject.eraseToAnyPublisher()
    }
    var canRedoPublisher: AnyPublisher<Bool, Never> {
        canRedoSubject.eraseToAnyPublisher()
    }
    var refreshCanvasPublisher: AnyPublisher<TextureLayerUndoObject, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }

    /// An undoManager with undo/redoCount
    private let undoManager: UndoManager = UndoManagerWithCount()

    private let canUndoSubject = CurrentValueSubject<Bool, Never>(true)
    private let canRedoSubject = CurrentValueSubject<Bool, Never>(true)

    private let refreshCanvasSubject = PassthroughSubject<TextureLayerUndoObject, Never>()

    init(undoCount: Int) {
        undoManager.levelsOfUndo = undoCount
    }

    func undo() {
        (undoManager as? UndoManagerWithCount)?.performUndo()
        updateUndoComponents()
    }
    func redo() {
        (undoManager as? UndoManagerWithCount)?.performRedo()
        updateUndoComponents()
    }
    func reset() {
        (undoManager as? UndoManagerWithCount)?.reset()
        updateUndoComponents()
    }

    func pushUndoObject(
        textureLayers: TextureLayers,
        undoObject: TextureLayerUndoObject,
        with device: MTLDevice
    ) {
        registerUndoAction(
            textureLayers: textureLayers,
            undoObject: undoObject,
            with: device
        )

        updateUndoComponents()
    }

    func updateUndoComponents() {
        canUndoSubject.send(undoManager.canUndo)
        canRedoSubject.send(undoManager.canRedo)
    }

    private func registerUndoAction(
        textureLayers: TextureLayers,
        undoObject: TextureLayerUndoObject,
        with device: MTLDevice
    ) {
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard let `self` else { return }

            // Push the current settings onto the UndoStack for a redo operation
            if let undoObject = textureLayers.getUndoObject(device: device) {
                self.registerUndoAction(
                    textureLayers: textureLayers,
                    undoObject: undoObject,
                    with: device
                )
            }

            // Reflect the Undo object on the screen
            self.updateView(withUndoObject: undoObject)
        }
    }

    private func updateView(withUndoObject undoObject: TextureLayerUndoObject) {
        updateUndoComponents()
        refreshCanvasSubject.send(undoObject)
    }

}
