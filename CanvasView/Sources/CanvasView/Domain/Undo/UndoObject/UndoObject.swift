//
//  UndoObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/21.
//

import Combine
import Foundation

public protocol UndoObject {
    /// The texture ID used for the undo operation
    var undoTextureUUID: UndoTextureId { get }

    /// The texture layer targeted by the undo operation
    var textureLayer: TextureLayerModel { get }

    /// A subject that emits an UndoObjectProtocol instance when the undo object is deallocated
    var deinitSubject: PassthroughSubject<UndoObject, Never> { get }
}
