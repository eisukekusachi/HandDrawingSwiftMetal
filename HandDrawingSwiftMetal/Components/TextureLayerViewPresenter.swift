//
//  TextureLayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import CanvasView
import Combine
import TextureLayerView
import UIKit
import SwiftUI

@MainActor
final class TextureLayerViewPresenter {

    @Published public var isAlphaSliderDragging: Bool = false

    private class TextureLayerViewPresenterController: ObservableObject {
        @Published public var arrowX: CGFloat = 0
    }

    private let viewModel = TextureLayerViewModel()

    private var layerViewController: UIHostingController<PopupWithArrowView<TextureLayerView>>!

    private var popupWithArrowView: PopupWithArrowView<TextureLayerView>!

    private let controller = TextureLayerViewPresenterController()

    private var cancellables = Set<AnyCancellable>()

    func toggleView() {
        layerViewController.view.isHidden = !layerViewController.view.isHidden
    }
    func hide() {
        layerViewController.view.isHidden = true
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

        viewModel.$isDragging
            .assign(to: \.isAlphaSliderDragging, on: self)
            .store(in: &cancellables)
    }

    @MainActor
    func initialize(
        textureLayers: any TextureLayersProtocol,
        popupConfiguration: PopupWithArrowConfiguration
    ) {
        viewModel.initialize(textureLayers: textureLayers)

        popupConfiguration.initialize(
            sourceView: layerViewController.view
        )
        controller.arrowX = popupConfiguration.arrowX
    }
}
