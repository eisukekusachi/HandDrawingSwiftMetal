//
//  ScaleManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Foundation

enum ScaleManager {

    static func getAspectFitFactor(sourceSize: CGSize, destinationSize: CGSize) -> CGFloat {

        let ratioWidth = destinationSize.width / sourceSize.width
        let ratioHeight = destinationSize.height / sourceSize.height

        return ratioWidth < ratioHeight ? ratioWidth : ratioHeight
    }

    static func getAspectFillFactor(sourceSize: CGSize, destinationSize: CGSize) -> CGFloat {

        let ratioWidth = destinationSize.width / sourceSize.width
        let ratioHeight = destinationSize.height / sourceSize.height

        return ratioWidth > ratioHeight ? ratioWidth : ratioHeight
    }

}
