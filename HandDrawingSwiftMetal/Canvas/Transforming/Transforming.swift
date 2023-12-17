//
//  Transforming.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import Foundation

/// This protocol provides functionality related to view transformations.
protocol Transforming {

    /// Stored transformation matrix
    var storedMatrix: CGAffineTransform { get set }

    /// Update the transformation based on view touches and return a new matrix
    func getMatrix(transformationData: TransformationData,
                   frameCenterPoint: CGPoint,
                   touchState: TouchState) -> CGAffineTransform?
}
