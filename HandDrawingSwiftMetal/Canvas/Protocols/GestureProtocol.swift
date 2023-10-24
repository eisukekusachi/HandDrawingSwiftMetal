//
//  GestureProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol GestureProtocol {
    var gestureRecognizer: UIGestureRecognizer? { get }
    var touchPointStorage: TouchPointStorageProtocol { get }

    init(view: UIView, delegate: AnyObject?)

    func clear()
}
