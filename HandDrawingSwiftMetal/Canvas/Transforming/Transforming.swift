//
//  MatrixManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/30.
//

import UIKit

class Transforming: TransformingProtocol {

    var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    func getMatrix(transformationData: TransformationData,
                   frameCenterPoint: CGPoint,
                   touchState: TouchState) -> CGAffineTransform? {
        guard let matrix = makeMatrix(transformationData: transformationData,
                                      centerPoint: frameCenterPoint) else { return nil }
        let newMatrix = storedMatrix.concatenating(matrix)

        if touchState == .ended {
            storedMatrix = newMatrix
        }

        return newMatrix
    }

    /// Generate a matrix from touch points and view size
    private func makeMatrix(transformationData: TransformationData, centerPoint: CGPoint) -> CGAffineTransform? {
        if let pointsA = transformationData.pointsA,
           let pointsB = transformationData.pointsB,
           let newMatrix = CGAffineTransform.makeMatrix(center: centerPoint,
                                                        pointsA: pointsA,
                                                        pointsB: pointsB,
                                                        counterRotate: true,
                                                        flipY: true) {
            return newMatrix

        } else {
            return nil
        }
    }
}
