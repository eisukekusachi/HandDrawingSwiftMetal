//
//  FingerInputGestureRecognizer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/31.
//

import UIKit

@MainActor protocol FingerInputGestureRecognizerSender: AnyObject {
    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView)
}

final class FingerInputGestureRecognizer: UIGestureRecognizer {

    private weak var gestureDelegate: FingerInputGestureRecognizerSender?

    init(delegate: FingerInputGestureRecognizerSender) {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        gestureDelegate = delegate
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .began
        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .changed
        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }

        // Determine if any active finger touches remain
        let remainingDirectTouches = (event?.allTouches ?? []).filter {
            $0.type == .direct &&
            $0.phase != .ended &&
            $0.phase != .cancelled
        }
        state = remainingDirectTouches.isEmpty ? .ended : .changed

        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }

        // Determine if any active finger touches remain
        let remainingDirectTouches = (event?.allTouches ?? []).filter {
            $0.type == .direct &&
            $0.phase != .ended &&
            $0.phase != .cancelled
        }
        state = remainingDirectTouches.isEmpty ? .cancelled : .changed

        gestureDelegate?.sendFingerTouches(touches, with: event, on: view)
    }
}
