//
//  UIButtonExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/10.
//

import UIKit

extension UIButton {

    func debounce() {
        self.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) { [unowned self] in
            self.isUserInteractionEnabled = true
        }
    }

}

