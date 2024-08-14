//
//  TextureLayerUndoManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/13.
//

import Foundation
import Combine

final class TextureLayerUndoManager: ObservableObject, UndoManagerProtocol {

    var addCurrentLayersToUndoStackPublisher: AnyPublisher<Void, Never> {
        addCurrentLayersToUndoStackSubject.eraseToAnyPublisher()
    }

    var canUndoPublisher: AnyPublisher<Bool, Never> {
        canUndoSubject.eraseToAnyPublisher()
    }
    var canRedoPublisher: AnyPublisher<Bool, Never> {
        canRedoSubject.eraseToAnyPublisher()
    }

    var refreshCanvasPublisher: AnyPublisher<TextureLayerUndoObject, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }

    /// An undoManager with undoCount and redoCount
    let undoManager: UndoManager = UndoManagerWithCount()

    private let addCurrentLayersToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let canUndoSubject = CurrentValueSubject<Bool, Never>(true)
    private let canRedoSubject = CurrentValueSubject<Bool, Never>(true)

    private let refreshCanvasSubject = PassthroughSubject<TextureLayerUndoObject, Never>()

    init() {
        undoManager.levelsOfUndo = 8
    }

    func addCurrentLayersToUndoStack() {
        addCurrentLayersToUndoStackSubject.send()
    }

    func undo() {
        (undoManager as? UndoManagerWithCount)?.performUndo()
        updateUndoComponents()
    }
    func redo() {
        (undoManager as? UndoManagerWithCount)?.performRedo()
        updateUndoComponents()
    }
    func clear() {
        (undoManager as? UndoManagerWithCount)?.clear()
        updateUndoComponents()
    }

    func updateUndoComponents() {
        canUndoSubject.send(undoManager.canUndo)
        canRedoSubject.send(undoManager.canRedo)
    }

    func addUndoObject(
        undoObject: TextureLayerUndoObject,
        layerManager: TextureLayerManager
    ) {
        registerDrawingUndoAction(
            with: undoObject,
            layerManager: layerManager
        )

        updateUndoComponents()
    }

    /// Registers an action to undo the drawing operation.
    private func registerDrawingUndoAction(
        with undoObject: TextureLayerUndoObject,
        layerManager: TextureLayerManager
    ) {
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard
                let `self`,
                layerManager.layers.count != 0
            else { return }

            self.registerDrawingUndoAction(
                with: .init(
                    index: layerManager.index,
                    layers: layerManager.layers
                ),
                layerManager: layerManager
            )

            updateUndoComponents()

            refreshCanvasSubject.send(undoObject)
        }
    }

}
