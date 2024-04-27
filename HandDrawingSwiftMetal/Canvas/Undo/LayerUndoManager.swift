//
//  LayerUndoManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/13.
//

import Foundation
import Combine

final class LayerUndoManager: ObservableObject, UndoManagerProtocol {

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> {
        addUndoObjectToUndoStackSubject.eraseToAnyPublisher()
    }

    var canUndoPublisher: AnyPublisher<Bool, Never> {
        canUndoSubject.eraseToAnyPublisher()
    }
    var canRedoPublisher: AnyPublisher<Bool, Never> {
        canRedoSubject.eraseToAnyPublisher()
    }

    var refreshCanvasPublisher: AnyPublisher<UndoObject, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }

    /// An undoManager with undoCount and redoCount
    let undoManager: UndoManager = UndoManagerWithCount()

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let canUndoSubject = CurrentValueSubject<Bool, Never>(true)
    private let canRedoSubject = CurrentValueSubject<Bool, Never>(true)

    private let refreshCanvasSubject = PassthroughSubject<UndoObject, Never>()

    init() {
        undoManager.levelsOfUndo = 8
    }

    func addUndoObjectToUndoStack() {
        addUndoObjectToUndoStackSubject.send()
    }

    func undo() {
        (undoManager as? UndoManagerWithCount)?.performUndo()
        updateUndoActivity()
    }
    func redo() {
        (undoManager as? UndoManagerWithCount)?.performRedo()
        updateUndoActivity()
    }
    func clear() {
        (undoManager as? UndoManagerWithCount)?.clear()
        updateUndoActivity()
    }

    func updateUndoActivity() {
        canUndoSubject.send(undoManager.canUndo)
        canRedoSubject.send(undoManager.canRedo)
    }

    func addUndoObject(
        undoObject: UndoObject,
        layerManager: LayerManager
    ) {
        registerDrawingUndoAction(
            with: undoObject,
            layerManager: layerManager
        )

        updateUndoActivity()
    }

    /// Registers an action to undo the drawing operation.
    private func registerDrawingUndoAction(
        with undoObject: UndoObject,
        layerManager: LayerManager
    ) {
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard
                let `self`,
                layerManager.layers.count != 0
            else { return }

            self.registerDrawingUndoAction(
                with: UndoObject(
                    index: layerManager.index,
                    layers: layerManager.layers
                ),
                layerManager: layerManager
            )

            updateUndoActivity()

            refreshCanvasSubject.send(undoObject)
        }
    }

}
