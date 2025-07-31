//
//  TextureLayerViewSettings.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/26.
//

import UIKit

/// A settings container for configuring the layout and positioning of `TextureLayerView`
struct TextureLayerViewSettings {

    /// The button that serves as an anchor point, positioning the layer view directly below it
    let anchorButton: UIView

    /// The view where the layer view will be added as a subview
    let destinationView: UIView

    /// The size of the layer view
    let size: CGSize

    var arrowX: CGFloat {
        let targetViewCenterX = anchorButton.convert(anchorButton.bounds, to: destinationView).midX
        let layerViewX = targetViewCenterX - size.width * 0.5
        let centerX = targetViewCenterX - layerViewX
        return centerX
    }

    init(
        anchorButton: UIView,
        destinationView: UIView,
        size: CGSize
    ) {
        precondition(size.width > 0 && size.height > 0, "Width and height must be positive values")

        self.anchorButton = anchorButton
        self.destinationView = destinationView
        self.size = size
    }

    func configureViewLayout(
        sourceView: UIView
    ) {
        destinationView.addSubview(sourceView)

        sourceView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sourceView.topAnchor.constraint(equalTo: anchorButton.bottomAnchor),
            sourceView.centerXAnchor.constraint(equalTo: anchorButton.centerXAnchor),
            sourceView.widthAnchor.constraint(equalToConstant: size.width),
            sourceView.heightAnchor.constraint(equalToConstant: size.height)
        ])

        sourceView.setNeedsLayout()
    }
}
