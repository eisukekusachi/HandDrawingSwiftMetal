//
//  PencilGesture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol PencilGestureSender {
    func drawOnCanvas(_ gesture: PencilGesture, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func touchEnded(_ gesture: PencilGesture)
    func cancel(_ gesture: PencilGesture)
}

class PencilGesture: GestureProtocol {
    var gestureRecognizer: UIGestureRecognizer?
    var touchPointStorage: TouchPointStorageProtocol = DefaultPointStorage()

    var delegate: PencilGestureSender?

    required init(view: UIView, delegate: AnyObject) {
        self.delegate = delegate as? PencilGestureSender

        gestureRecognizer = PencilGestureRecognizer(output: self)
        view.addGestureRecognizer(gestureRecognizer!)
    }

    func clear() {
        touchPointStorage.clear()
    }
}

extension PencilGesture: PencilGestureRecognizerSender {
    func sendLocations(_ input: PencilGestureRecognizer?, touchPointArray: [TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? DefaultPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointArray)

        let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
        delegate?.drawOnCanvas(self, iterator: iterator, touchState: touchState)

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }

    func cancel(_ input: PencilGestureRecognizer?) {
        delegate?.cancel(self)
    }
}
