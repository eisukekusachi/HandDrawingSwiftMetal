//
//  LayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import UIKit
import SwiftUI

final class LayerViewPresenter {

    private var layerViewController: UIHostingController<LayerView>?
    private var layerView: LayerView?

    func setupLayerViewPresenter(
        layerManager: ImageLayerManager,
        layerViewPresentation: LayerViewPresentation,
        targetView: UIView,
        didTapLayer: @escaping (LayerEntity) -> Void,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didTapVisibility: @escaping (LayerEntity, Bool) -> Void,
        didChangeAlpha: @escaping (LayerEntity, Int) -> Void,
        didEditTitle: @escaping (LayerEntity, String) -> Void,
        didMove: @escaping (LayerEntity, IndexSet, Int) -> Void,
        on viewController: UIViewController
    ) {
        layerView = LayerView(
            layerManager: layerManager,
            layerViewPresentation: layerViewPresentation,
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

        layerViewController = UIHostingController<LayerView>(rootView: layerView)
        viewController.view.addSubview(layerViewController!.view)

        layerViewController?.view.backgroundColor = .clear
        layerViewController?.view.isHidden = true

        addConstraints(
            targetView: targetView,
            layerViewPresentation: layerViewPresentation,
            on: viewController)
    }
    func toggleVisible() {
        if let isHidden = layerViewController?.view.isHidden {
            layerViewController?.view.isHidden = !isHidden
        }
    }

    private func addConstraints(
        targetView: UIView,
        layerViewPresentation: LayerViewPresentation,
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

        layerViewPresentation.arrowPointX = centerX
    }

}
