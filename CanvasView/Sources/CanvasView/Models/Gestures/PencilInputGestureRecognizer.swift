//
//  PencilInputGestureRecognizer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/03/31.
//

import UIKit

@MainActor protocol PencilInputGestureRecognizerSender: AnyObject {
    func sendPencilEstimatedTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView)
    func sendPencilActualTouches(_ touches: Set<UITouch>, on view: UIView)
}

final class PencilInputGestureRecognizer: UIGestureRecognizer {

    private weak var sender: PencilInputGestureRecognizerSender?

    init() {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [UITouch.TouchType.pencil.rawValue as NSNumber]
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    func setDelegate(sender: PencilInputGestureRecognizerSender, delegate: UIGestureRecognizerDelegate) {
        self.sender = sender
        self.delegate = delegate
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .began
        sender?.sendPencilEstimatedTouches(touches, with: event, on: view)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .changed
        sender?.sendPencilEstimatedTouches(touches, with: event, on: view)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .ended
        sender?.sendPencilEstimatedTouches(touches, with: event, on: view)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        state = .cancelled
        sender?.sendPencilEstimatedTouches(touches, with: event, on: view)
    }

    /// https://developer.apple.com/documentation/uikit/apple_pencil_interactions/handling_input_from_apple_pencil/
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        guard let view else { return }
        sender?.sendPencilActualTouches(touches, on: view)
    }
}
