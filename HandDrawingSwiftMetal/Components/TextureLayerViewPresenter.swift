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

    func toggleView() {
        layerViewController.view.isHidden = !layerViewController.view.isHidden
    }

    @MainActor func setupLayerViewPresenter(
        configuration: TextureLayerConfiguration,
        using viewSettings: TextureLayerViewSettings
    ) {
        layerView = TextureLayerView(
            arrowPointX: viewSettings.arrowX,
            viewModel: .init(
                configuration: configuration
            )
        )

        layerViewController = UIHostingController(rootView: layerView)
        layerViewController.view.backgroundColor = .clear
        layerViewController.view.isHidden = true

        viewSettings.configureViewLayout(
            sourceView: layerViewController.view
        )
    }

}
