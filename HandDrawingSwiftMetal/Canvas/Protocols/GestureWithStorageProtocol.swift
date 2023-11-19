//
//  GestureWithStorageProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

/// A protocol with UIGestureRecognizer and TouchPoint storage
protocol GestureWithStorageProtocol {
    var gestureRecognizer: UIGestureRecognizer? { get }
    var touchPointStorage: TouchPointStorageProtocol { get }

    init(view: UIView, delegate: AnyObject?)

    func clear()
}
