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

            view.addSubview(layerViewController.view)

            layerViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                layerViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
                layerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

                layerViewController.view.widthAnchor.constraint(equalToConstant: 300),
                layerViewController.view.heightAnchor.constraint(equalToConstant: 200)
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
