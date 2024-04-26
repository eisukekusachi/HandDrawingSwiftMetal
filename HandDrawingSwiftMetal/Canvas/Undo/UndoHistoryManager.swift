//
//  UndoHistoryManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/13.
//

import Foundation
import Combine

final class UndoHistoryManager: UndoManager, ObservableObject {

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> {
        addUndoObjectToUndoStackSubject.eraseToAnyPublisher()
    }

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    func addUndoObjectToUndoStack() {
        addUndoObjectToUndoStackSubject.send()
    }

    func registerDrawingUndoAction(delegate: CanvasViewModelDelegate?, layerManager: LayerManager) {
        guard
            let delegate,
            layerManager.layers.count != 0
        else { return }

        delegate.registerDrawingUndoAction(
            with: UndoObject(
                index: layerManager.index,
                layers: layerManager.layers
            )
        )

        layerManager.updateSelectedLayerTextureWithNewAddressTexture()
    }

}
