//
//  LayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import UIKit
import SwiftUI

final class LayerViewPresenter {

    private var layerViewController: UIHostingController<ImageLayerView<ImageLayerModel>>?
    private var layerView: ImageLayerView<ImageLayerModel>?

    private let roundedRectangleWithArrow = RoundedRectangleWithArrow()

    func setupLayerViewPresenter(
        layerManager: ImageLayerManager,
        targetView: UIView,
        didTapLayer: @escaping (ImageLayerModel) -> Void,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didTapVisibility: @escaping (ImageLayerModel, Bool) -> Void,
        didChangeAlpha: @escaping (ImageLayerModel, Int) -> Void,
        didEditTitle: @escaping (ImageLayerModel, String) -> Void,
        didMove: @escaping (ImageLayerModel, IndexSet, Int) -> Void,
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
    func toggleVisible() {
        if let isHidden = layerViewController?.view.isHidden {
            layerViewController?.view.isHidden = !isHidden
        }
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
