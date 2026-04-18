//
//  CGSizeExtensions.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/02/07.
//

import UIKit

extension CGSize {

    static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width * lhs.height < rhs.width * rhs.height
    }

    static func > (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width * lhs.height > rhs.width * rhs.height
    }

    static func <= (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width * lhs.height <= rhs.width * rhs.height
    }

    static func >= (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width * lhs.height >= rhs.width * rhs.height
    }

    static func == (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}
