//
//  UndoHistoryManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/13.
//

import Foundation
import Combine

final class UndoHistoryManager: ObservableObject {

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
    private let undoManager = UndoManagerWithCount()

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
        undoManager.performUndo()
        updateUndoActivity()
    }
    func redo() {
        undoManager.performRedo()
        updateUndoActivity()
    }
    func clear() {
        undoManager.clear()
        updateUndoActivity()
    }

    func updateUndoActivity() {
        canUndoSubject.send(undoManager.canUndo)
        canRedoSubject.send(undoManager.canRedo)
    }

    func registerDrawingUndoAction(
        layerManager: LayerManager,
        viewModel: CanvasViewModel
    ) {
        registerDrawingUndoAction(
            with: UndoObject(
                index: layerManager.index,
                layers: layerManager.layers
            ),
            viewModel: viewModel
        )

        updateUndoActivity()

        layerManager.updateSelectedLayerTextureWithNewAddressTexture()
    }

    /// Registers an action to undo the drawing operation.
    private func registerDrawingUndoAction(
        with undoObject: UndoObject,
        viewModel: CanvasViewModel
    ) {
        undoManager.registerUndo(withTarget: viewModel) { [weak self] _ in
            guard
                let `self`,
                viewModel.layerManager.layers.count != 0
            else { return }

            self.registerDrawingUndoAction(
                with: UndoObject(
                    index: viewModel.layerManager.index,
                    layers: viewModel.layerManager.layers
                ),
                viewModel: viewModel
            )

            updateUndoActivity()

            refreshCanvasSubject.send(undoObject)
        }
    }

}
