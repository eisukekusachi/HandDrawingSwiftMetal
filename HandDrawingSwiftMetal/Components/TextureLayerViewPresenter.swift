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
    func hide() {
        layerViewController.view.isHidden = true
    }

    func enableComponentInteraction(_ isUserInteractionEnabled: Bool) {
        layerViewController.view.isUserInteractionEnabled = isUserInteractionEnabled
    }

    init() {
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
    }

    func setup(
        configuration: PopupWithArrowConfiguration
    ) {
        configuration.initialize(
            sourceView: layerViewController.view
        )
        controller.arrowX = configuration.arrowX
    }

    func initialize(
        textureLayers: any TextureLayersProtocol
    ) {
        viewModel.initialize(textureLayers: textureLayers)
    }
}
