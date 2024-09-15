//
//  ViewSize.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/09/06.
//

import Foundation

enum ViewSize {

    static func getScaleToFit(_ source: CGSize, to destination: CGSize) -> CGFloat {
        let widthRatio = destination.width / source.width
        let heightRatio = destination.height / source.height

        return min(widthRatio, heightRatio)
    }

    static func getScaleToFill(_ source: CGSize, to destination: CGSize) -> CGFloat {
        let widthRatio = destination.width / source.width
        let heightRatio = destination.height / source.height

        return max(widthRatio, heightRatio)
    }

}
