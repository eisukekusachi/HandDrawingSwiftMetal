//
//  ActivityIndicatorView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/05.
//

import UIKit

class ActivityIndicatorView: UIView {

    private let indicator = UIActivityIndicatorView.init(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        addSubview(indicator)
        indicator.layer.cornerRadius = 8
        indicator.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        indicator.color = .gray
        indicator.startAnimating()

        backgroundColor = .init(white: 0.0, alpha: 0.2)
        indicator.backgroundColor = .init(white: 1.0, alpha: 0.75)
    }

    override func layoutSubviews() {
        indicator.center = center
    }
}
