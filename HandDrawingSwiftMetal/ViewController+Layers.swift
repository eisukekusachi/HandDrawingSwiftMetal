//
//  ViewController+Layers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import UIKit

extension ViewController {
    func toggleLayerVisibility() {
        if !existHostingController() {
            let marginRight: CGFloat = 8
            let viewWidth: CGFloat = 300.0
            let viewHeight: CGFloat = 300.0
            let viewX: CGFloat = view.frame.width - (viewWidth + marginRight)

            canvasViewModel.layerManager.arrowPointX = layerButton.convert(layerButton.bounds, to: view).midX - viewX

            view.addSubview(layerViewController.view)

            layerViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                layerViewController.view.topAnchor.constraint(equalTo: topStackView.bottomAnchor),
                layerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -marginRight),

                layerViewController.view.widthAnchor.constraint(equalToConstant: viewWidth),
                layerViewController.view.heightAnchor.constraint(equalToConstant: viewHeight)
            ])

            layerViewController.view.backgroundColor = .clear

        } else {
            layerViewController.view.removeFromSuperview()
        }
    }
    func existHostingController() -> Bool {
        return view.subviews.contains { subview in
            return subview == layerViewController.view
        }
    }
}
