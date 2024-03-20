//
//  UIViewExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit

extension UIView {

    func instantiateNib() {
        let nibName = String(describing: type(of: self))
        if let nib = Bundle.main.loadNibNamed(nibName, owner: self, options: nil)?.first as? UIView {
            nib.frame = bounds
            nib.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(nib)
        }
    }

}
