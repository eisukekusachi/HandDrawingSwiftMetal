//
//  PencilInput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol PencilInputSender {
    func drawOnCanvas(_ input: PencilInput, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func touchEnded(_ input: PencilInput)
    func cancel(_ input: PencilInput)
}

class PencilInput: InputProtocol {
    var gestureRecognizer: UIGestureRecognizer?
    var touchPointStorage: TouchPointStorageProtocol = DefaultPointStorage()

    var delegate: PencilInputSender?

    required init(view: UIView, delegate: AnyObject?) {
        self.delegate = delegate as? PencilInputSender

        gestureRecognizer = PencilGestureRecognizer(output: self)
        view.addGestureRecognizer(gestureRecognizer!)
    }

    func clear() {
        touchPointStorage.clear()
    }
}

extension PencilInput: PencilGestureRecognizerSender {
    func sendLocations(_ gesture: PencilGestureRecognizer?, touchPointArray: [TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? DefaultPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointArray)

        let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
        delegate?.drawOnCanvas(self, iterator: iterator, touchState: touchState)

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }

    func cancel(_ gesture: PencilGestureRecognizer?) {
        delegate?.cancel(self)
    }
}
