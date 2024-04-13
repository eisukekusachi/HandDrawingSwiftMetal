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
        layerManager: LayerManager,
        undoHistoryManager: UndoHistoryManager,
        targetView: UIView,
        on viewController: UIViewController
    ) {
        layerView = LayerView(
            layerManager: layerManager,
            undoHistoryManager: undoHistoryManager
        )

        guard let layerView else { return }

        layerViewController = UIHostingController<LayerView>(rootView: layerView)
        viewController.view.addSubview(layerViewController!.view)

        layerViewController?.view.backgroundColor = .clear
        layerViewController?.view.isHidden = true

        addConstraints(targetView: targetView, layerManager: layerManager, on: viewController)
    }
    func toggleVisible() {
        if let isHidden = layerViewController?.view.isHidden {
            layerViewController?.view.isHidden = !isHidden
        }
    }

    private func addConstraints(targetView: UIView, layerManager: LayerManager, on viewController: UIViewController) {
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

        layerManager.arrowPointX = centerX
    }
}
