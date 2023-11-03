//
//  InputProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

/// A protocol with UIGestureRecognizer and a TouchPoint storage
protocol InputProtocol {
    var gestureRecognizer: UIGestureRecognizer? { get }
    var touchPointStorage: TouchPointStorageProtocol { get }

    init(view: UIView, delegate: AnyObject?)

    func clear()
}
