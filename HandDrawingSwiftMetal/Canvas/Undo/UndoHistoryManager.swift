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

}
