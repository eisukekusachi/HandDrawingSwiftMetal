//
//  TextureLayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import CanvasView
import TextureLayerView
import UIKit
import SwiftUI

@MainActor
final class TextureLayerViewPresenter {

    private class TextureLayerViewPresenterController: ObservableObject {

        @Published public var arrowX: CGFloat = 0
    }

    private let viewModel = TextureLayerViewModel()

    private var layerViewController: UIHostingController<PopupWithArrowView<TextureLayerView>>!

    private var popupWithArrowView: PopupWithArrowView<TextureLayerView>!

    private let controller = TextureLayerViewPresenterController()

    func toggleView() {
        layerViewController.view.isHidden = !layerViewController.view.isHidden
    }

    @MainActor
    func initialize(
        configuration: TextureLayerConfiguration,
        popupConfiguration: PopupWithArrowConfiguration
    ) {
        viewModel.initialize(configuration: configuration)

        let layerView = TextureLayerView(
            viewModel: viewModel
        )

        popupWithArrowView = PopupWithArrowView(
            arrowPointX: Binding(
                get: { self.controller.arrowX },
                set: { self.controller.arrowX = $0 }
            )
        ) {
            layerView
        }

        layerViewController = UIHostingController(rootView: popupWithArrowView)
        layerViewController.view.backgroundColor = .clear
        layerViewController.view.isHidden = true

        popupConfiguration.initialize(
            sourceView: layerViewController.view
        )
        controller.arrowX = popupConfiguration.arrowX
    }
}
