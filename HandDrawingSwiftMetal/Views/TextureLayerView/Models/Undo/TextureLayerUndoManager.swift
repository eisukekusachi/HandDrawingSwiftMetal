//
//  TextureLayerUndoManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/13.
//

import Foundation
import Combine

final class TextureLayerUndoManager: ObservableObject {

    var addTextureLayersToUndoStackPublisher: AnyPublisher<Void, Never> {
        addTextureLayersToUndoStackSubject.eraseToAnyPublisher()
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

    private let addTextureLayersToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let canUndoSubject = CurrentValueSubject<Bool, Never>(true)
    private let canRedoSubject = CurrentValueSubject<Bool, Never>(true)

    private let refreshCanvasSubject = PassthroughSubject<TextureLayerUndoObject, Never>()

    init() {
        undoManager.levelsOfUndo = 8
    }

    func addCurrentLayersToUndoStack() {
        addTextureLayersToUndoStackSubject.send()
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
        registerUndoAction(
            with: undoObject,
            layerManager: layerManager
        )

        updateUndoComponents()
    }

    private func registerUndoAction(
        with undoObject: TextureLayerUndoObject,
        layerManager: TextureLayerManager
    ) {
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard
                let `self`,
                layerManager.layers.count != 0
            else { return }

            self.registerUndoAction(
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