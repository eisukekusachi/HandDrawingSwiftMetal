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
    func reset() {
        (undoManager as? UndoManagerWithCount)?.reset()
        updateUndoComponents()
    }

    func updateUndoComponents() {
        canUndoSubject.send(undoManager.canUndo)
        canRedoSubject.send(undoManager.canRedo)
    }

    func addUndoObject(
        undoObject: TextureLayerUndoObject,
        textureLayers: TextureLayers
    ) {
        registerUndoAction(
            with: undoObject,
            textureLayers: textureLayers
        )

        updateUndoComponents()
    }

    private func registerUndoAction(
        with undoObject: TextureLayerUndoObject,
        textureLayers: TextureLayers
    ) {
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard
                let `self`,
                textureLayers.layers.count != 0
            else { return }

            self.registerUndoAction(
                with: .init(
                    index: textureLayers.index,
                    layers: textureLayers.layers
                ),
                textureLayers: textureLayers
            )

            updateUndoComponents()

            refreshCanvasSubject.send(undoObject)
        }
    }

}
