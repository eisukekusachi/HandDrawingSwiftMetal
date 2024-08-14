//
//  LayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import UIKit
import SwiftUI

final class LayerViewPresenter {

    private var layerViewController: UIHostingController<ImageLayerView<TextureLayer>>?
    private var layerView: ImageLayerView<TextureLayer>?

    private let roundedRectangleWithArrow = RoundedRectangleWithArrow()

    func setupLayerViewPresenter(
        layerManager: TextureLayerManager,
        targetView: UIView,
        didTapLayer: @escaping (TextureLayer) -> Void,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didTapVisibility: @escaping (TextureLayer, Bool) -> Void,
        didChangeAlpha: @escaping (TextureLayer, Int) -> Void,
        didEditTitle: @escaping (TextureLayer, String) -> Void,
        didMove: @escaping (TextureLayer, IndexSet, Int) -> Void,
        on viewController: UIViewController
    ) {
        layerView = ImageLayerView(
            layerManager: layerManager,
            roundedRectangleWithArrow: roundedRectangleWithArrow,
            didTapLayer: { layer in
                didTapLayer(layer)
            },
            didTapAddButton: {
                didTapAddButton()
            },
            didTapRemoveButton: {
                didTapRemoveButton()
            },
            didTapVisibility: { entity, value in
                didTapVisibility(entity, value)
            },
            didChangeAlpha: { entity, value in
                didChangeAlpha(entity, value)
            },
            didEditTitle: { entity, value in
                didEditTitle(entity, value)
            },
            didMove: { layer, source, destination in
                didMove(layer, source, destination)
            }
        )

        guard let layerView else { return }

        layerViewController = UIHostingController<ImageLayerView>(rootView: layerView)
        viewController.view.addSubview(layerViewController!.view)

        layerViewController?.view.backgroundColor = .clear
        layerViewController?.view.isHidden = true

        addConstraints(
            targetView: targetView,
            roundedRectangleWithArrow: roundedRectangleWithArrow,
            on: viewController
        )
    }
    func showView(_ isShown: Bool) {
        layerViewController?.view.isHidden = !isShown
    }

    private func addConstraints(
        targetView: UIView,
        roundedRectangleWithArrow: RoundedRectangleWithArrow,
        on viewController: UIViewController
    ) {
        let viewWidth: CGFloat = 300.0
        let viewHeight: CGFloat = 300.0

        layerViewController?.view.translatesAutoresizingMaskIntoConstraints = false

        layerViewController?.view.topAnchor.constraint(equalTo: targetView.bottomAnchor).isActive = true
        layerViewController?.view.centerXAnchor.constraint(equalTo: targetView.centerXAnchor).isActive = true
        layerViewController?.view.widthAnchor.constraint(equalToConstant: viewWidth).isActive = true
        layerViewController?.view.heightAnchor.constraint(equalToConstant: viewHeight).isActive = true

        layerViewController?.view.setNeedsLayout()

        let targetViewCenterX = targetView.convert(targetView.bounds, to: viewController.view).midX
        let layerViewX = targetViewCenterX - viewWidth * 0.5
        let centerX = targetViewCenterX - layerViewX

        roundedRectangleWithArrow.arrowPointX = centerX
    }

}
