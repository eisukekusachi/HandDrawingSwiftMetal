//
//  UndoManagerProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/27.
//

import UIKit
import Combine

protocol UndoManagerProtocol {

    var undoManager: UndoManager { get }

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> { get }
    var canUndoPublisher: AnyPublisher<Bool, Never> { get }
    var canRedoPublisher: AnyPublisher<Bool, Never> { get }

    func undo()
    func redo()
    func clear()
    func updateUndoComponents()
}
