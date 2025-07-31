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

    @MainActor
    func initialize(
        configuration: TextureLayerConfiguration,
        popupConfiguration: PopupWithArrowConfiguration
    ) {
        layerView = TextureLayerView(
            configuration: configuration
        )

        layerViewController = UIHostingController(rootView: layerView)
        layerViewController.view.backgroundColor = .clear
        layerViewController.view.isHidden = true

        popupConfiguration.initialize(
            sourceView: layerViewController.view
        )

        layerView.updateArrowX(popupConfiguration.arrowX)
    }
}
