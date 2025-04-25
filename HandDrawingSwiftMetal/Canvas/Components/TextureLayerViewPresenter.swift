//
//  TextureLayerViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/20.
//

import UIKit
import SwiftUI

final class TextureLayerViewPresenter {

    private var layerViewController: UIHostingController<TextureLayerView>!
    private var layerView: TextureLayerView!

    private let roundedRectangleWithArrow = RoundedRectangleWithArrow()

    func setupLayerViewPresenter(
        canvasState: CanvasState,
        targetView: UIView,
        on destinationView: UIView
    ) {
        layerView = TextureLayerView(
            textureLayers: .init(
                canvasState: canvasState
            ),
            roundedRectangleWithArrow: roundedRectangleWithArrow
        )

        guard let layerView else { return }

        layerViewController = UIHostingController<TextureLayerView>(rootView: layerView)
        destinationView.addSubview(layerViewController.view)

        layerViewController.view.backgroundColor = .clear
        layerViewController.view.isHidden = true

        addConstraints(
            targetView: targetView,
            roundedRectangleWithArrow: roundedRectangleWithArrow,
            on: destinationView
        )
    }
    func showView(_ isShown: Bool) {
        layerViewController.view.isHidden = !isShown
    }

    private func addConstraints(
        targetView: UIView,
        roundedRectangleWithArrow: RoundedRectangleWithArrow,
        on destinationView: UIView
    ) {
        let viewWidth: CGFloat = 300.0
        let viewHeight: CGFloat = 300.0

        layerViewController.view.translatesAutoresizingMaskIntoConstraints = false

        layerViewController.view.topAnchor.constraint(equalTo: targetView.bottomAnchor).isActive = true
        layerViewController.view.centerXAnchor.constraint(equalTo: targetView.centerXAnchor).isActive = true
        layerViewController.view.widthAnchor.constraint(equalToConstant: viewWidth).isActive = true
        layerViewController.view.heightAnchor.constraint(equalToConstant: viewHeight).isActive = true

        layerViewController.view.setNeedsLayout()

        let targetViewCenterX = targetView.convert(targetView.bounds, to: destinationView).midX
        let layerViewX = targetViewCenterX - viewWidth * 0.5
        let centerX = targetViewCenterX - layerViewX

        roundedRectangleWithArrow.arrowPointX = centerX
    }

}
