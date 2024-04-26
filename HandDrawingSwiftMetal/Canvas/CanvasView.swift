//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

/// A user can use drawing tools to draw lines on the texture and then transform it.
class CanvasView: MTKTextureDisplayView {

    /// An undoManager with undoCount and redoCount
    let undoManagerWithCount = UndoManagerWithCount()

    private (set) var viewModel: CanvasViewModel?

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInitialization()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInitialization()
    }

    private func commonInitialization() {
        undoManagerWithCount.levelsOfUndo = 8
    }

    func setViewModel(_ viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

}
