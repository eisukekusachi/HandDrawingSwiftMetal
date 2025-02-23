//
//  DotPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/02/22.
//

import Foundation

protocol DotPoint: Equatable {

    var location: CGPoint { get }
    var diameter: CGFloat { get }

}
