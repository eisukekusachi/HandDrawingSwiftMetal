//
//  CGSizeExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/31.
//

import UIKit

extension CGSize {

    func isSameRatio(_ targetSize: CGSize) -> Bool {
        self.width / self.height == targetSize.width / targetSize.height
    }

}
