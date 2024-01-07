//
//  CanvasViewModel+Transforming.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/04.
//

import UIKit

// MARK: Transforming
extension CanvasViewModel {
    func getMatrix(transformationData: TransformationData,
                   frameCenterPoint: CGPoint,
                   touchState: TouchState) -> CGAffineTransform? {
        transforming.getMatrix(transformationData: transformationData,
                               frameCenterPoint: frameCenterPoint,
                               touchState: touchState)
    }
    func setStoredMatrix(_ matrix: CGAffineTransform) {
        transforming.setStoredMatrix(matrix)
    }
}
