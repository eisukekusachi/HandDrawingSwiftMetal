//
//  CanvasPencilInputGestureRecognizer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/31.
//

import UIKit

protocol CanvasPencilInputGestureRecognizerSender: AnyObject {
    func sendPencilTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView)
}

final class CanvasPencilInputGestureRecognizer: UIGestureRecognizer {

    weak var gestureDelegate: CanvasPencilInputGestureRecognizerSender?

    init() {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [UITouch.TouchType.pencil.rawValue as NSNumber]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendPencilTouches(touches, with: event, on: view)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendPencilTouches(touches, with: event, on: view)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendPencilTouches(touches, with: event, on: view)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        gestureDelegate?.sendPencilTouches(touches, with: event, on: view)
    }

}
