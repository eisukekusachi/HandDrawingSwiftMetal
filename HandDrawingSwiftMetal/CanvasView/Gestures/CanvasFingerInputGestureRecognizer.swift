//
//  CanvasFingerInputGestureRecognizer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/31.
//

import UIKit

protocol CanvasFingerInputGestureRecognizerSender: AnyObject {
    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView)
}

final class CanvasFingerInputGestureRecognizer: UIGestureRecognizer {

    weak var gestureDelegate: CanvasFingerInputGestureRecognizerSender?

    init() {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }

}
