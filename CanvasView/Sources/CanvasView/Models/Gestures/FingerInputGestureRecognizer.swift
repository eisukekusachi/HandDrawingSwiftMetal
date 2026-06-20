//
//  FingerInputGestureRecognizer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/03/31.
//

import UIKit

@MainActor protocol FingerInputGestureRecognizerSender: AnyObject {
    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView)
}

final class FingerInputGestureRecognizer: UIGestureRecognizer {

    private weak var sender: FingerInputGestureRecognizerSender?

    init() {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    func setDelegate(sender: FingerInputGestureRecognizerSender, delegate: UIGestureRecognizerDelegate) {
        self.sender = sender
        self.delegate = delegate
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .began
        sender?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .changed
        sender?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }

        // Determine if any active finger touches remain
        let remainingDirectTouches = (event?.allTouches ?? touches).filter {
            $0.type == .direct &&
            $0.phase != .ended &&
            $0.phase != .cancelled
        }
        state = remainingDirectTouches.isEmpty ? .ended : .changed

        sender?.sendFingerTouches(touches, with: event, on: view)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }

        // Determine if any active finger touches remain
        let remainingDirectTouches = (event?.allTouches ?? touches).filter {
            $0.type == .direct &&
            $0.phase != .ended &&
            $0.phase != .cancelled
        }
        state = remainingDirectTouches.isEmpty ? .cancelled : .changed

        sender?.sendFingerTouches(touches, with: event, on: view)
    }
}
