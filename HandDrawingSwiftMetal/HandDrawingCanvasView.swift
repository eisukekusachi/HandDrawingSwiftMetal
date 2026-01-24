//
//  HandDrawingCanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/22.
//

import CanvasView
import UIKit

@objc final class HandDrawingCanvasView: CanvasView {

    override init() {
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
