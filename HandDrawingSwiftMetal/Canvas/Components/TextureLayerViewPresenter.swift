//
//  TextureLayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import UIKit
import SwiftUI

final class TextureLayerViewPresenter {

    private var layerViewController: UIHostingController<TextureLayerView>!
    private var layerView: TextureLayerView!

    private let roundedRectangleWithArrow = RoundedRectangleWithArrow()

    func showView(_ isShown: Bool) {
        layerViewController.view.isHidden = !isShown
    }

    func setupLayerViewPresenter(
        canvasState: CanvasState,
        textureLayerRepository: TextureLayerRepository,
        undoStack: UndoStack?,
        using viewSettings: TextureLayerViewSettings
    ) {
        layerView = TextureLayerView(
            viewModel: .init(
                canvasState: canvasState,
                textureLayerRepository: textureLayerRepository,
                undoStack: undoStack
            ),
            roundedRectangleWithArrow: roundedRectangleWithArrow
        )

        layerViewController = UIHostingController(rootView: layerView)
        layerViewController.view.backgroundColor = .clear
        layerViewController.view.isHidden = true

        viewSettings.configureViewLayout(
            sourceView: layerViewController.view
        )

        roundedRectangleWithArrow.arrowPointX = viewSettings.arrowX()
    }

}
