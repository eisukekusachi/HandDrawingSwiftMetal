//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import UIKit

class CanvasView: UIView {

    let renderView = CanvasRenderView()

    init() {
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addSubview(renderView)
        renderView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            renderView.topAnchor.constraint(equalTo: topAnchor),
            renderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            renderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
