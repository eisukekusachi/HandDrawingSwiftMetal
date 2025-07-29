//
//  TextureLayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import CanvasView
import UIKit
import SwiftUI

final class TextureLayerViewPresenter {

    private var layerViewController: UIHostingController<TextureLayerView>!
    private var layerView: TextureLayerView!

    private let roundedRectangleWithArrow = RoundedRectangleWithArrow()

    func toggleView() {
        layerViewController.view.isHidden = !layerViewController.view.isHidden
    }

    @MainActor func setupLayerViewPresenter(
        configuration: TextureLayerConfiguration,
        using viewSettings: TextureLayerViewSettings
    ) {
        layerView = TextureLayerView(
            viewModel: .init(
                configuration: configuration
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
